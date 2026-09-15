#include "app_icon.h"

#include <QtGui/QGuiApplication>
#include <QtGui/QIcon>
#include <QtCore/QString>
#include <QtCore/QCoreApplication>
#include <QtCore/QLocale>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QStringList>
#include <QtCore/QTranslator>

namespace flufflinux {

void set_application_icon()
{
    const QIcon fallback(QStringLiteral(":/com/flufflinux/calculator/icon.svg"));
    QGuiApplication::setWindowIcon(
        QIcon::fromTheme(QStringLiteral("com.flufflinux.calculator"), fallback));
}

void install_application_translator()
{
    static QTranslator translator;
    QStringList languages;

    const QString environmentLanguages = qEnvironmentVariable("LANGUAGE");
    if (!environmentLanguages.trimmed().isEmpty()) {
        languages.append(environmentLanguages.split(QLatin1Char(':'),
                                                    Qt::SkipEmptyParts));
    }

    const QString plasmaLocalePath =
        QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/plasma-localerc");
    QSettings plasmaLocale(plasmaLocalePath, QSettings::IniFormat);
    plasmaLocale.beginGroup(QStringLiteral("Translations"));
    const QString configuredLanguages =
        plasmaLocale.value(QStringLiteral("LANGUAGE")).toString();
    plasmaLocale.endGroup();
    if (!configuredLanguages.trimmed().isEmpty()) {
        languages.append(configuredLanguages.split(QLatin1Char(':'),
                                                   Qt::SkipEmptyParts));
    }
    languages.append(QLocale::system().uiLanguages());

    QStringList candidates;
    for (QString language : languages) {
        language = language.trimmed().replace(QLatin1Char('-'), QLatin1Char('_'));
        if (language.isEmpty()) {
            continue;
        }
        if (!candidates.contains(language)) {
            candidates.append(language);
        }
        const QString baseLanguage = language.section(QLatin1Char('_'), 0, 0);
        if (!baseLanguage.isEmpty() && !candidates.contains(baseLanguage)) {
            candidates.append(baseLanguage);
        }
    }

    QStringList translationDirectories = QStandardPaths::locateAll(
        QStandardPaths::GenericDataLocation,
        QStringLiteral("flufflinux-calculator/translations"),
        QStandardPaths::LocateDirectory);
    translationDirectories.append(
        QStringLiteral(":/com/flufflinux/calculator/translations"));

    for (const QString &directory : translationDirectories) {
        for (const QString &language : candidates) {
            if (translator.load(QStringLiteral("flufflinux-calculator_") + language,
                                directory)) {
                QCoreApplication::installTranslator(&translator);
                QGuiApplication::setLayoutDirection(
                    QLocale(language).textDirection());
                return;
            }
        }
    }
}

}
