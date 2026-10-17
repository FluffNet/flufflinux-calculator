#include "app_icon.h"

#include <QtGui/QGuiApplication>
#include <QtGui/QIcon>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QCoreApplication>
#include <QtCore/QLocale>
#include <QtCore/QStandardPaths>
#include <QtCore/QTranslator>

namespace flufflinux {

void set_application_icon()
{
    const QIcon fallback(QStringLiteral(":/com/flufflinux/calculator/icon.svg"));
    QGuiApplication::setWindowIcon(
        QIcon::fromTheme(QStringLiteral("com.flufflinux.calculator"), fallback));
}

rust::Vec<rust::String> system_ui_languages()
{
    rust::Vec<rust::String> result;
    for (const QString &language : QLocale::system().uiLanguages()) {
        result.push_back(language.toStdString());
    }
    return result;
}

rust::Vec<rust::String> translation_directories()
{
    rust::Vec<rust::String> result;
    for (const QString &directory : QStandardPaths::locateAll(
             QStandardPaths::GenericDataLocation,
             QStringLiteral("flufflinux-calculator/translations"),
             QStandardPaths::LocateDirectory)) {
        result.push_back(directory.toStdString());
    }
    return result;
}

bool load_application_catalog(rust::Str path)
{
    static QTranslator translator;
    const QString filename = QString::fromUtf8(path.data(), static_cast<qsizetype>(path.size()));
    // Load the exact file. Qt's automatic filename truncation must not cross scripts.
    if (!translator.load(filename, QString(), QStringLiteral(""))) {
        return false;
    }
    return QCoreApplication::installTranslator(&translator);
}

void set_application_layout_direction(bool right_to_left)
{
    QGuiApplication::setLayoutDirection(right_to_left ? Qt::RightToLeft : Qt::LeftToRight);
}

}
