import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class aviaView extends WatchUi.WatchFace {

    private const C_RED   = 0xFF1A1A;
    private const C_BLUE  = 0x2233FF;
    private const C_WHITE = 0xFFFFFF;
    private const C_GREY  = 0x9A9A9A;
    private const C_FIELD = 0xD0D0D0;   // couleur du texte des champs

    // Aiguilles : facette claire / facette ombrée / contour
    private const HAND_LIGHT   = 0xFFFFFF;
    private const HAND_SHADE   = 0xB4B4B4;
    private const HAND_OUTLINE = 0x000000;

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
    private const SIZE_TEXT  = 28;   // champs 1 et 2 (haut / bas)
    private const SIZE_SIDE  = 22;   // champs 3 et 4 (droite / gauche)

    // Tailles des logos (base 400 px)
    private const ICON_BIG   = 24.0; // champs 1 et 2
    private const ICON_SIDE  = 18.0; // champs 3 et 4

    // Positions des champs (base 400 px, par rapport au centre)
    private const F1_Y = -55.0;      // haut
    private const F2_Y =  55.0;      // bas
    private const F3_X =  72.0;      // droite (centre du contenu)
    private const F4_X = -68.0;      // gauche

    // ---- Fuseaux horaires (même ordre que les entrées Zone0..Zone40 des réglages) ----
    // Règles d'heure d'été : 0 = aucune, 1 = Europe, 2 = USA/Canada,
    // 3 = Australie (sud-est), 4 = Nouvelle-Zélande
    private const ZONE_CODE = [
        "LON", "PAR", "ATH", "IST", "MOW", "DXB", "KBL", "KHI", "DEL", "KTM",
        "DAC", "BKK", "SIN", "HKG", "PER", "TYO", "ADL", "DRW", "SYD", "BNE",
        "NOU", "AKL", "HNL", "ANC", "LAX", "DEN", "PHX", "CHI", "MEX", "NYC",
        "BOG", "HAL", "CCS", "SAO", "BUE", "LOS", "JNB", "NBO", "TEH", "UTC",
        "REK"
    ];
    // Décalage UTC standard, en minutes
    private const ZONE_OFF = [
        0, 60, 120, 180, 180, 240, 270, 300, 330, 345,
        360, 420, 480, 480, 480, 540, 570, 570, 600, 600,
        660, 720, -600, -540, -480, -420, -420, -360, -360, -300,
        -300, -240, -240, -180, -180, 60, 120, 180, 210, 0,
        0
    ];
    private const ZONE_RULE = [
        1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 3, 0, 3, 0,
        0, 4, 0, 2, 2, 2, 0, 2, 0, 2,
        0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
        0
    ];

    private var _cx as Number = 195;
    private var _cy as Number = 195;
    private var _s as Float = 1.0;
    private var _lowPower as Boolean = false;
    private var _zone as Number = 0;      // fuseau secondaire choisi
    private var _fontNum as Graphics.VectorFont? = null;
    private var _fontSmall as Graphics.VectorFont? = null;
    private var _fontText as Graphics.VectorFont? = null;
    private var _fontSide as Graphics.VectorFont? = null;

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
            _fontSide = Graphics.getVectorFont({
                :face => ["RobotoCondensedBold", "RobotoCondensed", "Roboto"],
                :size => Math.round(SIZE_SIDE * _s).toNumber()
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

        // Options
        var showSeconds = getBool("ShowSeconds", true);
        var londonColor = getNum("LondonHandColor", C_RED);
        var batteryLit = getBool("BatteryLit", true);
        var showIcons = getBool("ShowIcons", true);
        var fieldsOver = getBool("FieldsOverHands", true);
        var f1 = getNum("Field1Type", 8);
        var f2 = getNum("Field2Type", 3);
        var f3 = getNum("Field3Type", 2);
        var f4 = getNum("Field4Type", 1);

        _zone = getNum("SecondTimeZone", 0);
        if (_zone < 0 || _zone >= ZONE_CODE.size()) {
            _zone = 0;
        }

        // Décor
        if (!_lowPower) {
            drawBezel(dc);
            drawOuterTicks(dc);
            drawMarkers(dc);
            drawNumerals(dc);
            drawBattery(dc, batteryLit);
        }

        // Champs derrière les aiguilles (option désactivée)
        if (!_lowPower && !fieldsOver) {
            drawFields(dc, f1, f2, f3, f4, showIcons, false);
        }

        // Aiguilles
        drawHands(dc, h, m, sc);

        if (!_lowPower && showSeconds) {
            drawSecond(dc, sc);
        }
        drawLondonHand(dc, londonColor);

        // Champs devant les aiguilles (option activée), avec contour noir
        if (!_lowPower && fieldsOver) {
            drawFields(dc, f1, f2, f3, f4, showIcons, true);
        }

        drawCenter(dc);
    }

    // ---------- Lecture des options ----------

    private function getBool(key as String, def as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        if (v instanceof Boolean) {
            return v as Boolean;
        }
        return def;
    }

    private function getNum(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v as Number;
        }
        return def;
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

    // Texte aligné à gauche
    private function txtLeft(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                             fallback as Graphics.FontDefinition, s as String) as Void {
        if (vf != null) {
            dc.drawText(x, y, vf, s,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(x, y, fallback, s,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function textWidth(dc as Dc, vf as Graphics.VectorFont?,
                               fallback as Graphics.FontDefinition, s as String) as Number {
        if (vf != null) {
            return dc.getTextWidthInPixels(s, vf);
        }
        return dc.getTextWidthInPixels(s, fallback);
    }

    // ---------- Décor ----------

    private function drawBezel(dc as Dc) as Void {
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.0));
        dc.drawCircle(_cx, _cy, 197 * _s);
    }

    // Anneau extérieur : un trait long par heure impaire (1, 3, 5, ... 23)
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

    // Jauge batterie : 101 traits, long tous les 10 %, 9 petits entre chaque
    private function drawBattery(dc as Dc, lit as Boolean) as Void {
        var level = System.getSystemStats().battery;

        for (var v = 0; v <= 100; v++) {
            var ang = GAUGE_START + v * GAUGE_SWEEP / 100.0;
            var major = (v % 10 == 0);
            var on = (!lit) || (v <= level);
            dc.setColor(on ? 0xCCCCCC : 0x444444, Graphics.COLOR_TRANSPARENT);
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

    // ---------- Champs personnalisables ----------

    // Les 4 champs d'un coup (appelé avant ou après les aiguilles selon l'option)
    private function drawFields(dc as Dc, f1 as Number, f2 as Number, f3 as Number,
                                f4 as Number, showIcons as Boolean, halo as Boolean) as Void {
        // Champ 1 (haut)
        drawField(dc, _cx, _cy + F1_Y * _s, f1, _fontText, Graphics.FONT_SMALL,
                  ICON_BIG, showIcons, halo);
        // Champ 2 (bas)
        drawField(dc, _cx, _cy + F2_Y * _s, f2, _fontText, Graphics.FONT_SMALL,
                  ICON_BIG, showIcons, halo);
        // Champ 3 (droite, sans fond)
        drawField(dc, _cx + F3_X * _s, _cy, f3, _fontSide, Graphics.FONT_XTINY,
                  ICON_SIDE, showIcons, halo);
        // Champ 4 (gauche)
        drawField(dc, _cx + F4_X * _s, _cy, f4, _fontSide, Graphics.FONT_XTINY,
                  ICON_SIDE, showIcons, halo);
    }

    // Id du logo : types 1 à 7 ont un logo (1 cœur, 2 éclair, 3 horloge,
    // 4 pieds, 5 flamme, 6 repère, 7 stress). Les autres types n'en ont pas.
    private function fieldIcon(type as Number) as Number {
        return (type >= 1 && type <= 7) ? type : 0;
    }

    // Texte du champ. Sans logo, on ajoute le libellé (HR, BB, REC...).
    private function fieldText(type as Number, showIcons as Boolean) as String {
        if (type == 0) {
            return "";
        }
        var v = fieldValue(type);
        if (type >= 1 && type <= 7 && !showIcons) {
            var labels = ["", "HR", "BB", "REC", "STEPS", "CAL", "KM", "STR"];
            return labels[type] + " " + v;
        }
        return v;
    }

    private function fieldValue(type as Number) as String {
        if (type == 1) {
            var hr = getHeartRate();
            return (hr != null) ? hr.format("%d") : "--";
        }
        if (type == 2) {
            var bb = getBodyBattery();
            return (bb != null) ? bb.format("%d") : "--";
        }
        if (type == 3) {
            var info = ActivityMonitor.getInfo();
            if (info has :timeToRecovery) {
                var r = info.timeToRecovery;
                if (r != null) {
                    return (r as Number).format("%d") + "H";
                }
            }
            return "--";
        }
        if (type == 4) {
            var st = ActivityMonitor.getInfo().steps;
            return (st != null) ? st.format("%d") : "--";
        }
        if (type == 5) {
            var cal = ActivityMonitor.getInfo().calories;
            return (cal != null) ? cal.format("%d") : "--";
        }
        if (type == 6) {
            var dist = ActivityMonitor.getInfo().distance;   // en cm
            if (dist != null) {
                return ((dist as Number) / 100000.0).format("%.1f") + "KM";
            }
            return "--";
        }
        if (type == 7) {
            var stress = getStress();
            return (stress != null) ? stress.format("%d") : "--";
        }
        if (type == 8) {
            // Heure du fuseau secondaire, avec le code de la ville
            var t = secondInfo();
            return (ZONE_CODE[_zone] as String) + " "
                + t.hour.format("%02d") + ":" + t.min.format("%02d");
        }
        if (type == 9) {
            var c = System.getClockTime();
            var hh = c.hour;
            if (!System.getDeviceSettings().is24Hour) {
                hh = hh % 12;
                if (hh == 0) { hh = 12; }
            }
            return hh.format("%02d") + ":" + c.min.format("%02d");
        }
        if (type == 10) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return (d.day as Number).format("%02d");
        }
        if (type == 11) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var days = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"];
            var dow = (d.day_of_week as Number) - 1;   // 1 = dimanche
            if (dow < 0 || dow > 6) { dow = 0; }
            return (d.day as Number).format("%02d") + " "
                + (d.month as Number).format("%02d") + " " + days[dow];
        }
        return "";
    }

    // Largeur logo + espace
    private function iconWidth(icon as Number, isz as Float) as Float {
        return (icon > 0) ? (isz * _s + 4 * _s) : 0.0;
    }

    // Dessine logo + texte centrés sur (cx, cy). halo = contour noir autour du texte
    private function drawField(dc as Dc, cx as Numeric, cy as Numeric, type as Number,
                               vf as Graphics.VectorFont?, fallback as Graphics.FontDefinition,
                               isz as Float, showIcons as Boolean, halo as Boolean) as Void {
        if (type == 0) { return; }
        var icon = showIcons ? fieldIcon(type) : 0;
        var text = fieldText(type, showIcons);
        var tw = textWidth(dc, vf, fallback, text);
        var iw = iconWidth(icon, isz);
        var x = cx - (tw + iw) / 2;

        if (icon > 0) {
            drawIcon(dc, icon, x + isz * _s / 2, cy, isz * _s / 2);
        }

        if (halo) {
            var o = px(1.5);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            txtLeft(dc, x + iw - o, cy, vf, fallback, text);
            txtLeft(dc, x + iw + o, cy, vf, fallback, text);
            txtLeft(dc, x + iw, cy - o, vf, fallback, text);
            txtLeft(dc, x + iw, cy + o, vf, fallback, text);
        }

        dc.setColor(C_FIELD, Graphics.COLOR_TRANSPARENT);
        txtLeft(dc, x + iw, cy, vf, fallback, text);
    }

    // ---------- Logos dessinés par le code ----------

    private function q(x as Float, y as Float) as [Numeric, Numeric] {
        return [ x, y ] as [Numeric, Numeric];
    }

    // Centré sur (x, y), r = demi-taille
    private function drawIcon(dc as Dc, id as Number, x as Float, y as Float, r as Float) as Void {
        if (id == 1) {
            // Cœur
            dc.setColor(0xFF3355, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 0.5 * r, y - 0.3 * r, 0.52 * r);
            dc.fillCircle(x + 0.5 * r, y - 0.3 * r, 0.52 * r);
            dc.fillPolygon([
                q(x - 0.98 * r, y - 0.1 * r), q(x + 0.98 * r, y - 0.1 * r), q(x, y + r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 2) {
            // Éclair (Body Battery)
            dc.setColor(0x33CCFF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                q(x + 0.15 * r, y - r), q(x - 0.55 * r, y + 0.1 * r), q(x - 0.05 * r, y + 0.1 * r),
                q(x - 0.2 * r, y + r), q(x + 0.55 * r, y - 0.15 * r), q(x + 0.05 * r, y - 0.15 * r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 3) {
            // Horloge (récupération)
            dc.setColor(0x66DD66, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(px(2.0));
            dc.drawCircle(x, y, 0.9 * r);
            dc.drawLine(x, y, x, y - 0.55 * r);
            dc.drawLine(x, y, x + 0.4 * r, y);
        } else if (id == 4) {
            // Pas : deux empreintes
            dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 0.45 * r, y + 0.35 * r, 0.38 * r);
            dc.fillCircle(x - 0.45 * r, y - 0.3 * r, 0.25 * r);
            dc.fillCircle(x + 0.45 * r, y + 0.1 * r, 0.38 * r);
            dc.fillCircle(x + 0.45 * r, y - 0.55 * r, 0.25 * r);
        } else if (id == 5) {
            // Flamme (calories)
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y + 0.35 * r, 0.6 * r);
            dc.fillPolygon([
                q(x - 0.55 * r, y + 0.2 * r), q(x + 0.55 * r, y + 0.2 * r), q(x + 0.1 * r, y - r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 6) {
            // Repère de position (distance)
            dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 0.35 * r, 0.6 * r);
            dc.fillPolygon([
                q(x - 0.5 * r, y - 0.05 * r), q(x + 0.5 * r, y - 0.05 * r), q(x, y + r)
            ] as Array<[Numeric, Numeric]>);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 0.35 * r, 0.22 * r);
        } else if (id == 7) {
            // Courbe de stress
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(px(2.0));
            dc.drawLine(x - r, y, x - 0.5 * r, y);
            dc.drawLine(x - 0.5 * r, y, x - 0.25 * r, y - 0.8 * r);
            dc.drawLine(x - 0.25 * r, y - 0.8 * r, x + 0.1 * r, y + 0.8 * r);
            dc.drawLine(x + 0.1 * r, y + 0.8 * r, x + 0.4 * r, y - 0.3 * r);
            dc.drawLine(x + 0.4 * r, y - 0.3 * r, x + 0.5 * r, y);
            dc.drawLine(x + 0.5 * r, y, x + r, y);
        }
    }

    // ---------- Lecture des données ----------

    private function getHeartRate() as Number? {
        // Valeur en direct
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate as Number;
        }
        // Sinon, dernier échantillon connu
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var sample = it.next();
        if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return sample.heartRate as Number;
        }
        return null;
    }

    private function getBodyBattery() as Number? {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            if (it != null) {
                var sample = it.next();
                if (sample != null && sample.data != null) {
                    return (sample.data as Numeric).toNumber();
                }
            }
        }
        return null;
    }

    private function getStress() as Number? {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            var it = SensorHistory.getStressHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            if (it != null) {
                var sample = it.next();
                if (sample != null && sample.data != null) {
                    return (sample.data as Numeric).toNumber();
                }
            }
        }
        return null;
    }

    // ---------- Aiguilles ----------

    // Lame à deux facettes : moitié gauche cL, moitié droite cR (relief)
    private function blade(dc as Dc, angle as Float, len as Float, w as Float,
                           tail as Float, cL as Number, cR as Number) as Void {
        dc.setColor(cL, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            pt(angle, 0.0, -tail), pt(angle, -w * 0.35, -tail),
            pt(angle, -w * 0.5, len * 0.18), pt(angle, 0.0, len)
        ] as Array<[Numeric, Numeric]>);
        dc.setColor(cR, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            pt(angle, 0.0, -tail), pt(angle, w * 0.35, -tail),
            pt(angle, w * 0.5, len * 0.18), pt(angle, 0.0, len)
        ] as Array<[Numeric, Numeric]>);
    }

    // Aiguille stylisée : contour noir puis lame à deux facettes
    private function drawLeaf(dc as Dc, angle as Float, len as Float, w as Float,
                              tail as Float) as Void {
        blade(dc, angle, len + 2.0, w + 5.0, tail + 2.0, HAND_OUTLINE, HAND_OUTLINE);
        blade(dc, angle, len, w, tail, HAND_LIGHT, HAND_SHADE);
    }

    // Heures et minutes locales
    private function drawHands(dc as Dc, h as Number, m as Number, sc as Number) as Void {
        var hourAngle = ((h % 12) + m / 60.0) * 30.0;
        var minAngle = m * 6.0 + sc * 0.1;

        drawLeaf(dc, hourAngle, 112.0, 24.0, 12.0);
        drawLeaf(dc, minAngle, 175.0, 18.0, 12.0);
    }

    // Trotteuse : aiguille fine blanche avec contour noir
    private function drawSecond(dc as Dc, sc as Number) as Void {
        var ang = sc * 6.0;
        dc.setColor(HAND_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(5.0));
        line(dc, ang, -40.0, 177.0);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2.5));
        line(dc, ang, -40.0, 177.0);
    }

    // Aiguille rouge : heure du fuseau secondaire sur l'échelle 24 h
    private function drawLondonHand(dc as Dc, color as Number) as Void {
        var t = secondInfo();
        var ang = (t.hour + t.min / 60.0) * 15.0;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
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

    // ---------- Fuseau horaire secondaire ----------

    // Décale un moment de secs secondes (positif ou négatif)
    private function shift(m as Time.Moment, secs as Number) as Time.Moment {
        if (secs >= 0) {
            return m.add(new Time.Duration(secs));
        }
        return m.subtract(new Time.Duration(-secs));
    }

    // Dimanche du mois à 00:00 UTC. which : 1 = premier, 2 = deuxième, 0 = dernier
    private function sundayOf(year as Number, month as Number, which as Number,
                              daysInMonth as Number) as Time.Moment {
        if (which == 0) {
            var last = Gregorian.moment({
                :year => year, :month => month, :day => daysInMonth, :hour => 0
            });
            var dowL = Gregorian.utcInfo(last, Time.FORMAT_SHORT).day_of_week;  // 1 = dimanche
            return last.subtract(new Time.Duration((dowL - 1) * 86400));
        }
        var first = Gregorian.moment({
            :year => year, :month => month, :day => 1, :hour => 0
        });
        var dowF = Gregorian.utcInfo(first, Time.FORMAT_SHORT).day_of_week;
        var days = ((8 - dowF) % 7) + 7 * (which - 1);
        return first.add(new Time.Duration(days * 86400));
    }

    // Heure d'été active pour ce fuseau à cet instant ?
    private function isDst(now as Time.Moment, offMin as Number, rule as Number) as Boolean {
        if (rule == 0) {
            return false;
        }
        var year = Gregorian.utcInfo(now, Time.FORMAT_SHORT).year;
        var off = offMin * 60;

        if (rule == 1) {
            // Europe : dernier dimanche de mars -> dernier dimanche d'octobre, à 01:00 UTC
            var st1 = shift(sundayOf(year, 3, 0, 31), 3600);
            var en1 = shift(sundayOf(year, 10, 0, 31), 3600);
            return (!now.lessThan(st1)) && now.lessThan(en1);
        }
        if (rule == 2) {
            // USA / Canada : 2e dimanche de mars -> 1er dimanche de novembre, à 02:00 locale
            var st2 = shift(sundayOf(year, 3, 2, 31), 7200 - off);
            var en2 = shift(sundayOf(year, 11, 1, 30), 3600 - off);
            return (!now.lessThan(st2)) && now.lessThan(en2);
        }
        if (rule == 3) {
            // Australie (sud-est) : 1er dimanche d'octobre -> 1er dimanche d'avril
            var st3 = shift(sundayOf(year, 10, 1, 31), 7200 - off);
            var en3 = shift(sundayOf(year, 4, 1, 30), 7200 - off);
            return (!now.lessThan(st3)) || now.lessThan(en3);
        }
        if (rule == 4) {
            // Nouvelle-Zélande : dernier dimanche de septembre -> 1er dimanche d'avril
            var st4 = shift(sundayOf(year, 9, 0, 30), 7200 - off);
            var en4 = shift(sundayOf(year, 4, 1, 30), 7200 - off);
            return (!now.lessThan(st4)) || now.lessThan(en4);
        }
        return false;
    }

    // Date et heure dans le fuseau secondaire (à lire avec les champs hour et min)
    private function secondInfo() as Gregorian.Info {
        var now = Time.now();
        var off = ZONE_OFF[_zone] as Number;
        var rule = ZONE_RULE[_zone] as Number;
        var secs = off * 60;
        if (isDst(now, off, rule)) {
            secs += 3600;
        }
        return Gregorian.utcInfo(shift(now, secs), Time.FORMAT_SHORT);
    }
}