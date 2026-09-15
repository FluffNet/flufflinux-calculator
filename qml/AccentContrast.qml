import QtQuick

QtObject {
    function isNeutral(color) {
        return color.hsvSaturation <= 0.18
    }

    function luminance(color) {
        return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
    }

    function fillColor(color) {
        if (isNeutral(color))
            return color

        const hue = color.hsvHue >= 0 ? color.hsvHue : 0
        return Qt.hsva(hue,
                       Math.max(color.hsvSaturation, 0.69),
                       Math.min(color.hsvValue, 0.52),
                       1.0)
    }

    function textColor(color, darkTheme) {
        if (isNeutral(color))
            return luminance(color) < 0.5 ? "#ffffff" : "#000000"
        return darkTheme ? "#ffffff" : "#000000"
    }
}
