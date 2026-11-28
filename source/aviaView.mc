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

    // Tailles de police du décor (base 400 px)
    private const SIZE_NUM   = 34;  // numéros 24h
    private const SIZE_SMALL = 20;  // numéros batterie + "Battery"

    // ===== CHAMPS DE DONNÉES : réglages indépendants =====
    // Pour chaque champ : taille du texte, gras, taille du logo, couleur du texte,
    // épaisseur du contour, position.
    // Positions en base 400 px par rapport au centre (x vers la droite, y vers le bas).
    // La couleur ne change que le texte : chaque logo garde sa couleur propre.

    // Contour des données (suit la forme du texte et des logos)
    private const BORDER_COLOR = 0x000000;  // couleur du contour
    private const BORDER_ICONS = true;      // contour aussi sur les logos
    // Épaisseur du contour par champ (base 400 px). 0.0 = pas de contour.
    // Au-delà de 3.0, le contour peut devenir irrégulier.
    private const BORDER_F1 = 2.0;
    private const BORDER_F2 = 2.0;
    private const BORDER_F3 = 2.0;
    private const BORDER_F4 = 2.0;
    private const BORDER_F5 = 2.0;

    // Champ 1 : haut
    private const SIZE_F1 = 48;
    private const BOLD_F1 = false;
    private const ICON_F1 = 24.0;
    private const COL_F1  = 0xFFFFFF;
    private const F1_X    = 0.0;
    private const F1_Y    = -66.0;

    // Champ 2 : bas
    private const SIZE_F2 = 40;
    private const BOLD_F2 = false;
    private const ICON_F2 = 15.0;
    private const COL_F2  = 0xFFFFFF;
    private const F2_X    = 0.0;
    private const F2_Y    = 66.0;

    // Champ 3 : gauche, sous le champ 4
    private const SIZE_F3 = 43;
    private const BOLD_F3 = true;
    private const ICON_F3 = 20.0;
    private const COL_F3  = 0xFFFFFF;
    private const F3_X    = -70.0;
    private const F3_Y    = 22.0;

    // Champ 4 : gauche (heart rate)
    private const SIZE_F4 = 43;
    private const BOLD_F4 = true;
    private const ICON_F4 = 17.0;
    private const COL_F4  = 0xFFFFFF;
    private const F4_X    = -67.0;
    private const F4_Y    = -21.0;

    // Champ 5 : droite, jour de la semaine au-dessus du jour du mois
    // (même taille, même police et même couleur pour les deux lignes)
    private const SHOW_F5 = true;
    private const SIZE_F5 = 33;
    private const BOLD_F5 = true;
    private const COL_F5  = 0xFFFFFF;
    private const F5_X    = 72.0;
    private const F5_Y    = 0.0;
    private const F5_GAP  = 32.0;   // distance entre les deux lignes (0 = superposées)

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
    private var _iconMono as Number = -1; // >= 0 : logos dessinés d'une seule couleur (contour)
    private var _fontNum as Graphics.VectorFont? = null;
    private var _fontSmall as Graphics.VectorFont? = null;
    private var _fontF1 as Graphics.VectorFont? = null;
    private var _fontF2 as Graphics.VectorFont? = null;
    private var _fontF3 as Graphics.VectorFont? = null;
    private var _fontF4 as Graphics.VectorFont? = null;
    private var _fontF5 as Graphics.VectorFont? = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        _s = dc.getWidth() / 400.0;

        _fontNum = makeFont(true, SIZE_NUM);
        _fontSmall = makeFont(false, SIZE_SMALL);
        _fontF1 = makeFont(BOLD_F1, SIZE_F1);
        _fontF2 = makeFont(BOLD_F2, SIZE_F2);
        _fontF3 = makeFont(BOLD_F3, SIZE_F3);
        _fontF4 = makeFont(BOLD_F4, SIZE_F4);
        _fontF5 = makeFont(BOLD_F5, SIZE_F5);
    }

    // Police vectorielle condensée (gras ou non), mise à l'échelle de l'écran
    private function makeFont(bold as Boolean, size as Number) as Graphics.VectorFont? {
        if (!(Graphics has :getVectorFont)) {
            return null;
        }
        var face = bold
            ? ["RobotoCondensedBold", "RobotoCondensed", "Roboto"]
            : ["RobotoCondensedRegular", "RobotoCondensed", "Roboto"];
        return Graphics.getVectorFont({
            :face => face,
            :size => Math.round(size * _s).toNumber()
        });
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
        var fieldsOver = getBool("FieldsAbove", true);
        var f1 = getNum("Field1Type", 9);   // 8 = fuseau secondaire, 9 = heure numérique
        var f2 = getNum("Field2Type", 3);
        var f3 = getNum("Field3Type", 2);
        var f4 = getNum("Field4Type", 1);

        _zone = getNum("SecondTimeZone", 0);
        if (_zone < 0 || _zone >= ZONE_CODE.size()) {
            _zone = 0;
        }

        // En veille : le cadran reste affiché, seule la trotteuse disparaît.
        // Mettre keepDialAsleep à false pour revenir à l'ancien comportement
        // (aiguilles seules en veille).
        var keepDialAsleep = true;
        var showDial = (!_lowPower) || keepDialAsleep;

        // Décor
        if (showDial) {
            drawBezel(dc);
            drawOuterTicks(dc);
            drawMarkers(dc);
            drawNumerals(dc);
            drawBattery(dc, batteryLit);
        }

        // Champs derrière les aiguilles (option désactivée)
        if (showDial && !fieldsOver) {
            drawFields(dc, f1, f2, f3, f4, showIcons);
        }

        // Aiguille du fuseau secondaire : sous les feuilles heures / minutes
        drawLondonHand(dc, londonColor);

        // Feuilles heures et minutes
        drawHands(dc, h, m, sc);

        // Trotteuse : uniquement quand l'écran est actif
        if (!_lowPower && showSeconds) {
            drawSecond(dc, sc);
        }

        // Champs devant les aiguilles (option activée)
        if (showDial && fieldsOver) {
            drawFields(dc, f1, f2, f3, f4, showIcons);
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

    // Texte avec justification au choix : police vectorielle si dispo, sinon police système
    private function txtJ(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                          fallback as Graphics.FontDefinition, s as String, just as Number) as Void {
        if (vf != null) {
            dc.drawText(x, y, vf, s, just);
        } else {
            dc.drawText(x, y, fallback, s, just);
        }
    }

    // Texte centré
    private function txt(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                         fallback as Graphics.FontDefinition, s as String) as Void {
        txtJ(dc, x, y, vf, fallback, s,
             Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Texte aligné à gauche
    private function txtLeft(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                             fallback as Graphics.FontDefinition, s as String) as Void {
        txtJ(dc, x, y, vf, fallback, s,
             Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Décalage diagonal d'un contour d'épaisseur o (en pixels)
    private function diag(o as Number) as Number {
        return (o * 0.85 + 0.5).toNumber();
    }

    // Contour du texte : copies décalées dans 8 directions, à dessiner AVANT le texte.
    // width = épaisseur en base 400 px, 0.0 = pas de contour.
    private function outlineText(dc as Dc, x as Numeric, y as Numeric, vf as Graphics.VectorFont?,
                                 fallback as Graphics.FontDefinition, s as String,
                                 just as Number, width as Float) as Void {
        if (width <= 0.0) { return; }
        var o = px(width);
        var d = diag(o);
        dc.setColor(BORDER_COLOR, Graphics.COLOR_TRANSPARENT);
        txtJ(dc, x + o, y, vf, fallback, s, just);
        txtJ(dc, x - o, y, vf, fallback, s, just);
        txtJ(dc, x, y + o, vf, fallback, s, just);
        txtJ(dc, x, y - o, vf, fallback, s, just);
        txtJ(dc, x + d, y + d, vf, fallback, s, just);
        txtJ(dc, x - d, y + d, vf, fallback, s, just);
        txtJ(dc, x + d, y - d, vf, fallback, s, just);
        txtJ(dc, x - d, y - d, vf, fallback, s, just);
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

    // Les 5 champs d'un coup (appelé avant ou après les aiguilles selon l'option)
    private function drawFields(dc as Dc, f1 as Number, f2 as Number, f3 as Number,
                                f4 as Number, showIcons as Boolean) as Void {
        // Champ 1 (haut)
        drawField(dc, _cx + F1_X * _s, _cy + F1_Y * _s, f1, _fontF1, Graphics.FONT_SMALL,
                  ICON_F1, COL_F1, BORDER_F1, showIcons);
        // Champ 2 (bas)
        drawField(dc, _cx + F2_X * _s, _cy + F2_Y * _s, f2, _fontF2, Graphics.FONT_SMALL,
                  ICON_F2, COL_F2, BORDER_F2, showIcons);
        // Champ 3 (gauche, sous le champ 4)
        drawField(dc, _cx + F3_X * _s, _cy + F3_Y * _s, f3, _fontF3, Graphics.FONT_XTINY,
                  ICON_F3, COL_F3, BORDER_F3, showIcons);
        // Champ 4 (gauche)
        drawField(dc, _cx + F4_X * _s, _cy + F4_Y * _s, f4, _fontF4, Graphics.FONT_XTINY,
                  ICON_F4, COL_F4, BORDER_F4, showIcons);
        // Champ 5 (droite : jour de la semaine + jour du mois)
        if (SHOW_F5) {
            drawField5(dc);
        }
    }

    // Champ 5 : jour de la semaine au-dessus du jour du mois, même police et couleur
    private function drawField5(dc as Dc) as Void {
        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"];
        var dow = (d.day_of_week as Number) - 1;   // 1 = dimanche
        if (dow < 0 || dow > 6) { dow = 0; }
        var weekday = days[dow];
        var dayNum = (d.day as Number).format("%02d");

        var x = _cx + F5_X * _s;
        var half = F5_GAP * _s / 2;
        var yTop = _cy + F5_Y * _s - half;
        var yBottom = _cy + F5_Y * _s + half;
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Contour d'abord, puis le texte par-dessus
        outlineText(dc, x, yTop, _fontF5, Graphics.FONT_SMALL, weekday, just, BORDER_F5);
        outlineText(dc, x, yBottom, _fontF5, Graphics.FONT_SMALL, dayNum, just, BORDER_F5);

        dc.setColor(COL_F5, Graphics.COLOR_TRANSPARENT);
        txt(dc, x, yTop, _fontF5, Graphics.FONT_SMALL, weekday);
        txt(dc, x, yBottom, _fontF5, Graphics.FONT_SMALL, dayNum);
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
            return c.hour.format("%02d") + ":" + c.min.format("%02d");
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

    // Dessine logo + texte centrés sur (cx, cy), avec contour (bw = épaisseur, 0.0 = aucun)
    private function drawField(dc as Dc, cx as Numeric, cy as Numeric, type as Number,
                               vf as Graphics.VectorFont?, fallback as Graphics.FontDefinition,
                               isz as Float, color as Number, bw as Float,
                               showIcons as Boolean) as Void {
        if (type == 0) { return; }
        var icon = showIcons ? fieldIcon(type) : 0;
        var text = fieldText(type, showIcons);
        var tw = textWidth(dc, vf, fallback, text);
        var iw = iconWidth(icon, isz);
        var x = cx - (tw + iw) / 2;
        var ix = x + isz * _s / 2;
        var ir = isz * _s / 2;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        // 1. Contours (logo puis texte)
        if (icon > 0 && BORDER_ICONS) {
            outlineIcon(dc, icon, ix, cy, ir, bw);
        }
        outlineText(dc, x + iw, cy, vf, fallback, text, just, bw);

        // 2. Logo puis texte par-dessus
        if (icon > 0) {
            drawIcon(dc, icon, ix, cy, ir);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        txtLeft(dc, x + iw, cy, vf, fallback, text);
    }

    // ---------- Logos dessinés par le code ----------

    private function q(x as Float, y as Float) as [Numeric, Numeric] {
        return [ x, y ] as [Numeric, Numeric];
    }

    // Couleur d'un logo : sa couleur propre, ou la couleur unique du contour
    private function ic(c as Number) as Number {
        return (_iconMono >= 0) ? _iconMono : c;
    }

    // Contour d'un logo : sa silhouette dessinée en une seule couleur, décalée dans 8 directions
    private function outlineIcon(dc as Dc, id as Number, x as Float, y as Float, r as Float,
                                 width as Float) as Void {
        if (width <= 0.0) { return; }
        var o = px(width);
        var d = diag(o);
        _iconMono = BORDER_COLOR;
        drawIcon(dc, id, x + o, y, r);
        drawIcon(dc, id, x - o, y, r);
        drawIcon(dc, id, x, y + o, r);
        drawIcon(dc, id, x, y - o, r);
        drawIcon(dc, id, x + d, y + d, r);
        drawIcon(dc, id, x - d, y + d, r);
        drawIcon(dc, id, x + d, y - d, r);
        drawIcon(dc, id, x - d, y - d, r);
        _iconMono = -1;
    }

    // Centré sur (x, y), r = demi-taille
    private function drawIcon(dc as Dc, id as Number, x as Float, y as Float, r as Float) as Void {
        if (id == 1) {
            // Cœur
            dc.setColor(ic(0xFF3355), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 0.5 * r, y - 0.3 * r, 0.52 * r);
            dc.fillCircle(x + 0.5 * r, y - 0.3 * r, 0.52 * r);
            dc.fillPolygon([
                q(x - 0.98 * r, y - 0.1 * r), q(x + 0.98 * r, y - 0.1 * r), q(x, y + r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 2) {
            // Éclair (Body Battery)
            dc.setColor(ic(0x33CCFF), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                q(x + 0.15 * r, y - r), q(x - 0.55 * r, y + 0.1 * r), q(x - 0.05 * r, y + 0.1 * r),
                q(x - 0.2 * r, y + r), q(x + 0.55 * r, y - 0.15 * r), q(x + 0.05 * r, y - 0.15 * r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 3) {
            // Horloge (récupération)
            dc.setColor(ic(0x66DD66), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(px(2.0));
            dc.drawCircle(x, y, 0.9 * r);
            dc.drawLine(x, y, x, y - 0.55 * r);
            dc.drawLine(x, y, x + 0.4 * r, y);
        } else if (id == 4) {
            // Pas : deux empreintes
            dc.setColor(ic(0xDDDDDD), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 0.45 * r, y + 0.35 * r, 0.38 * r);
            dc.fillCircle(x - 0.45 * r, y - 0.3 * r, 0.25 * r);
            dc.fillCircle(x + 0.45 * r, y + 0.1 * r, 0.38 * r);
            dc.fillCircle(x + 0.45 * r, y - 0.55 * r, 0.25 * r);
        } else if (id == 5) {
            // Flamme (calories)
            dc.setColor(ic(0xFF8800), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y + 0.35 * r, 0.6 * r);
            dc.fillPolygon([
                q(x - 0.55 * r, y + 0.2 * r), q(x + 0.55 * r, y + 0.2 * r), q(x + 0.1 * r, y - r)
            ] as Array<[Numeric, Numeric]>);
        } else if (id == 6) {
            // Repère de position (distance)
            dc.setColor(ic(0x44AAFF), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 0.35 * r, 0.6 * r);
            dc.fillPolygon([
                q(x - 0.5 * r, y - 0.05 * r), q(x + 0.5 * r, y - 0.05 * r), q(x, y + r)
            ] as Array<[Numeric, Numeric]>);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 0.35 * r, 0.22 * r);
        } else if (id == 7) {
            // Courbe de stress
            dc.setColor(ic(0xFF8844), Graphics.COLOR_TRANSPARENT);
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

    // Rectangle le long de l'aiguille : de v0 à v1, demi-largeur hw
    private function bar(dc as Dc, angle as Float, v0 as Float, v1 as Float, hw as Float) as Void {
        dc.fillPolygon([
            pt(angle, -hw, v0), pt(angle, hw, v0),
            pt(angle, hw, v1),  pt(angle, -hw, v1)
        ] as Array<[Numeric, Numeric]>);
    }

    // Triangle agrandi ou réduit de k autour de son centre (cv = position du centre sur l'axe)
    private function tri(dc as Dc, angle as Float, hw as Float, base as Float, tip as Float,
                         cv as Float, k as Float) as Void {
        var vb = cv + k * (base - cv);
        dc.fillPolygon([
            pt(angle, -hw * k, vb),
            pt(angle, hw * k, vb),
            pt(angle, 0.0, cv + k * (tip - cv))
        ] as Array<[Numeric, Numeric]>);
    }

    // Aiguille du fuseau secondaire sur l'échelle 24 h :
    // tige rouge + triangle au bord rouge et au centre plein noir, le tout bordé
    private function drawLondonHand(dc as Dc, color as Number) as Void {
        // Réglages (base 400 px)
        var tail = -20.0;         // queue derrière le centre
        var base = 143.0;         // base du triangle
        var tip = 174.0;          // pointe du triangle
        var halfW = 11.0;         // demi-largeur du triangle
        var stemW = 1.0;          // demi-épaisseur de la tige
        var edge = 2.0;           // épaisseur du bord rouge du triangle
        var border = 3.0;         // épaisseur de la bordure autour de l'aiguille
        var borderColor = 0x000000;
        var fillColor = 0x000000;

        var t = secondInfo();
        var ang = (t.hour + t.min / 60.0) * 15.0;

        // Centre du triangle et rayon de son cercle inscrit (pour des bords réguliers)
        var h = tip - base;
        var leg = Math.sqrt(halfW * halfW + h * h);
        var inr = halfW * h / (leg + halfW);
        var cv = (leg * base + halfW * tip) / (leg + halfW);
        var kOut = 1.0 + border / inr;
        var kIn = 1.0 - edge / inr;

        // 1. Bordure autour de la tige et du triangle
        dc.setColor(borderColor, Graphics.COLOR_TRANSPARENT);
        bar(dc, ang, tail - border, base, stemW + border);
        tri(dc, ang, halfW, base, tip, cv, kOut);

        // 2. Tige et triangle rouges
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        bar(dc, ang, tail, base, stemW);
        tri(dc, ang, halfW, base, tip, cv, 1.0);

        // 3. Centre du triangle plein noir
        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        tri(dc, ang, halfW, base, tip, cv, kIn);
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