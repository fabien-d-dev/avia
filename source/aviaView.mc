import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class aviaView extends WatchUi.WatchFace {

    private const C_RED   = 0xFF1A1A;
    private const C_BLUE  = 0x2233FF;
    private const C_WHITE = 0xFFFFFF;
    private const C_GREY  = 0x9A9A9A;

    // Jauge batterie : 0 à 16°, 100 à 344° (degrés depuis le haut)
    private const GAUGE_START = 16.0;
    private const GAUGE_SWEEP = 328.0;

    // Rayons ajustables (base 400 px, mis à l'échelle automatiquement)
    private const NUM_R   = 170.0;  // numéros 24h
    private const LABEL_R = 111.0;  // numéros batterie

    // Graduations batterie : long tous les 10 %, 9 petits entre chaque
    private const BAT_R_IN    = 132.0;
    private const BAT_R_MAJOR = 150.0;
    private const BAT_R_MINOR = 141.0;

    // Anneau extérieur : traits longs uniquement
    private const RING_R_IN   = 172.0;
    private const RING_R_HOUR = 188.0;

    // Tailles de police (base 400 px)
    private const SIZE_NUM   = 34;
    private const SIZE_SMALL = 20;
    private const SIZE_TEXT  = 28;
    private const SIZE_DATE  = 26;

    private var _cx as Number = 195;
    private var _cy as Number = 195;
    private var _s as Float = 1.0;
    private var _lowPower as Boolean = false;
    private var _fontNum as Graphics.VectorFont? = null;
    private var _fontSmall as Graphics.VectorFont? = null;
    private var _fontText as Graphics.VectorFont? = null;
    private var _fontDate as Graphics.VectorFont? = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        _s = dc.getWidth() / 400.0;

        if (Graphics has :getVectorFont) {
            _fontNum = Graphics.getVectorFont({
                :face => ["RobotoCondensedBold", "RobotoCondensed", "Roboto"],
                :size => Math.round(SIZE_NUM * _s).toNumber()
            });
            _fontSmall = Graphics.getVectorFont({
                :face => ["RobotoCondensedRegular", "RobotoCondensed", "Roboto"],
                :size => Math.round(SIZE_SMALL * _s).toNumber()
            });
            _fontText = Graphics.getVectorFont({
                :face => ["RobotoCondensedRegular", "RobotoCondensed", "Roboto"],
                :size => Math.round(SIZE_TEXT * _s).toNumber()
            });
            _fontDate = Graphics.getVectorFont({
                :face => ["RobotoCondensedBold", "RobotoCondensed", "Roboto"],
                :size => Math.round(SIZE_DATE * _s).toNumber()
            });
        }
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var clock = System.getClockTime();
        var h = clock.hour;
        var m = clock.min;
        var sc = clock.sec;

        // Décor et textes (derrière les aiguilles)
        if (!_lowPower) {
            drawBezel(dc);
            drawOuterTicks(dc);
            drawMarkers(dc);
            drawNumerals(dc);
            drawBattery(dc);
            drawTexts(dc);
            drawDate(dc);
        }

        // Aiguilles (devant)
        drawHands(dc, h, m, sc);

        if (!_lowPower) {
            drawSecond(dc, sc);
        }
        drawLondonHand(dc);
        drawCenter(dc);
    }

    // ---------- Outils géométriques ----------

    // u = latéral, v = le long de l'aiguille, angle en degrés depuis le haut
    private function rot(angle as Float, u as Float, v as Float) as Array<Float> {
        var a = Math.toRadians(angle);
        var sn = Math.sin(a);
        var cs = Math.cos(a);
        return [ _cx + (v * sn + u * cs) * _s, _cy + (-v * cs + u * sn) * _s ];
    }

    private function pt(angle as Float, u as Float, v as Float) as [Numeric, Numeric] {
        var p = rot(angle, u, v);
        return [ p[0], p[1] ] as [Numeric, Numeric];
    }

    private function px(v as Float) as Number {
        var n = (v * _s + 0.5).toNumber();
        return (n < 1) ? 1 : n;
    }

    private function line(dc as Dc, angle as Float, r0 as Float, r1 as Float) as Void {
        var p0 = rot(angle, 0.0, r0);
        var p1 = rot(angle, 0.0, r1);
        dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
    }

    // Texte centré : police vectorielle si dispo, sinon police système de secours
    private function txt(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                         fallback as Graphics.FontDefinition, s as String) as Void {
        if (vf != null) {
            dc.drawText(x, y, vf, s,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(x, y, fallback, s,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---------- Décor ----------

    private function drawBezel(dc as Dc) as Void {
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.0));
        dc.drawCircle(_cx, _cy, 197 * _s);
    }

    // Anneau extérieur : un trait long par heure impaire (1, 3, 5, ... 23)
    // Les heures paires sont occupées par les numéros et les liserais
    private function drawOuterTicks(dc as Dc) as Void {
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.5));
        for (var hr = 1; hr < 24; hr += 2) {
            line(dc, hr * 15.0, RING_R_IN, RING_R_HOUR);
        }
    }

    // Repères bleu-blanc-rouge tous les 60°, décalés de 30°
    private function drawMarkers(dc as Dc) as Void {
        var colors = [C_BLUE, C_WHITE, C_RED];  // intérieur -> extérieur
        for (var i = 0; i < 6; i++) {
            var ang = (30 + i * 60).toFloat();
            for (var k = 0; k < 3; k++) {
                var r0 = 162.0 + k * 10.0;
                var r1 = r0 + 10.0;
                dc.setColor(colors[k], Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    pt(ang, -3.0, r0), pt(ang, 3.0, r0),
                    pt(ang, 3.0, r1),  pt(ang, -3.0, r1)
                ] as Array<[Numeric, Numeric]>);
            }
        }
    }

    // Échelle 24h : 24 en haut, 12 en bas
    private function drawNumerals(dc as Dc) as Void {
        var nums = ["24", "4", "8", "12", "16", "20"];
        var f = _fontNum;
        if (f == null) { return; }
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var ang = i * 60;
            dc.drawRadialText(_cx, _cy, f, nums[i],
                Graphics.TEXT_JUSTIFY_CENTER, 90 - ang, NUM_R * _s,
                Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
        }
    }

    // Jauge batterie : 101 traits (un par %), long tous les 10 %, 9 petits entre chaque
    private function drawBattery(dc as Dc) as Void {
        var level = System.getSystemStats().battery;

        for (var v = 0; v <= 100; v++) {
            var ang = GAUGE_START + v * GAUGE_SWEEP / 100.0;
            var major = (v % 10 == 0);
            dc.setColor((v <= level) ? 0xCCCCCC : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(px(major ? 3.0 : 1.0));
            line(dc, ang, BAT_R_IN, major ? BAT_R_MAJOR : BAT_R_MINOR);
        }

        // Numéros 0, 10, ... 100
        var f = _fontSmall;
        if (f != null) {
            dc.setColor(C_GREY, Graphics.COLOR_TRANSPARENT);
            for (var v = 0; v <= 100; v += 10) {
                var ang = GAUGE_START + v * GAUGE_SWEEP / 100.0;
                dc.drawRadialText(_cx, _cy, f, v.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER, 90 - ang, LABEL_R * _s,
                    Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            }
        }

        dc.setColor(C_GREY, Graphics.COLOR_TRANSPARENT);
        txt(dc, _cx, _cy - 142 * _s, _fontSmall, Graphics.FONT_XTINY, "Battery");
    }

    private function drawTexts(dc as Dc) as Void {
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);

        // Heure de Londres
        var now = Time.now();
        var london = now.add(new Time.Duration(londonOffset(now)));
        var t = Gregorian.utcInfo(london, Time.FORMAT_SHORT);
        var lon = "LON " + t.hour.format("%02d") + ":" + t.min.format("%02d");
        txt(dc, _cx, _cy - 55 * _s, _fontText, Graphics.FONT_SMALL, lon);

        // Pas
        var steps = ActivityMonitor.getInfo().steps;
        if (steps == null) { steps = 0; }
        txt(dc, _cx, _cy + 55 * _s, _fontText, Graphics.FONT_SMALL,
            steps.format("%d") + " STEPS");
    }

    private function drawDate(dc as Dc) as Void {
        var day = (Gregorian.info(Time.now(), Time.FORMAT_SHORT).day as Number);
        var x = _cx + 48 * _s;
        var y = _cy - 17 * _s;
        var w = 50 * _s;
        var h = 30 * _s;

        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 5 * _s);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x, y + h / 2, x + w, y + h / 2);

        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        txt(dc, x + w / 2, y + h / 2, _fontDate, Graphics.FONT_SMALL, day.format("%02d"));
    }

    // ---------- Aiguilles ----------

    private function drawLeaf(dc as Dc, angle as Float, len as Float, w as Float,
                              tail as Float, inner as Boolean) as Void {
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            pt(angle, -w * 0.35, -tail), pt(angle, -w * 0.5, len * 0.18),
            pt(angle, 0.0, len),
            pt(angle, w * 0.5, len * 0.18), pt(angle, w * 0.35, -tail)
        ] as Array<[Numeric, Numeric]>);
        if (inner) {
            dc.setColor(0x2B2B2B, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                pt(angle, -w * 0.18, 6.0), pt(angle, -w * 0.25, len * 0.18),
                pt(angle, 0.0, len * 0.82),
                pt(angle, w * 0.25, len * 0.18), pt(angle, w * 0.18, 6.0)
            ] as Array<[Numeric, Numeric]>);
        }
    }

    // Heures et minutes locales (feuilles blanches)
    private function drawHands(dc as Dc, h as Number, m as Number, sc as Number) as Void {
        var hourAngle = ((h % 12) + m / 60.0) * 30.0;
        var minAngle = m * 6.0 + sc * 0.1;

        drawLeaf(dc, hourAngle, 112.0, 24.0, 12.0, true);
        drawLeaf(dc, minAngle, 175.0, 18.0, 12.0, true);
    }

    // Trotteuse : aiguille fine blanche
    private function drawSecond(dc as Dc, sc as Number) as Void {
        var ang = sc * 6.0;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.5));
        line(dc, ang, -40.0, 177.0);
    }

    // Aiguille rouge : heure de Londres sur l'échelle 24 h
    private function drawLondonHand(dc as Dc) as Void {
        var now = Time.now();
        var london = now.add(new Time.Duration(londonOffset(now)));
        var t = Gregorian.utcInfo(london, Time.FORMAT_SHORT);
        var ang = (t.hour + t.min / 60.0) * 15.0;

        dc.setColor(C_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.0));
        line(dc, ang, -20.0, 150.0);

        // Triangle creux au bout
        var a = rot(ang, -11.0, 143.0);
        var b = rot(ang, 11.0, 143.0);
        var c = rot(ang, 0.0, 174.0);
        dc.drawLine(a[0], a[1], c[0], c[1]);
        dc.drawLine(b[0], b[1], c[0], c[1]);
        dc.drawLine(a[0], a[1], b[0], b[1]);
    }

    private function drawCenter(dc as Dc) as Void {
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 11 * _s);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 7 * _s);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 3.5 * _s);
    }

    // ---------- Heure de Londres (GMT / BST) ----------

    private function lastSunday(year as Number, month as Number) as Time.Moment {
        var last = Gregorian.moment({ :year => year, :month => month, :day => 31, :hour => 1 });
        var dow = Gregorian.utcInfo(last, Time.FORMAT_SHORT).day_of_week;  // 1 = dimanche
        return last.subtract(new Time.Duration((dow - 1) * 86400));
    }

    private function londonOffset(now as Time.Moment) as Number {
        var year = Gregorian.utcInfo(now, Time.FORMAT_SHORT).year;
        var start = lastSunday(year, 3);
        var end = lastSunday(year, 10);
        if (now.greaterThan(start) && now.lessThan(end)) {
            return 3600;
        }
        return 0;
    }
}