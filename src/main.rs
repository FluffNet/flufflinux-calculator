mod app_icon;
mod backend;
mod complex;
mod engine;
mod precise;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QQuickStyle, QUrl};

fn main() {
    QGuiApplication::set_desktop_file_name(&"com.flufflinux.calculator".into());
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    app_icon::set_application_icon();
    app_icon::install_application_translator();
    QQuickStyle::set_style(&"org.kde.desktop".into());

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from(
            "qrc:/qt/qml/com/flufflinux/calculator/qml/Main.qml",
        ));
    }
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
