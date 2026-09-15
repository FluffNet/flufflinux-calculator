use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    unsafe {
        CxxQtBuilder::new_qml_module(
            QmlModule::new("com.flufflinux.calculator")
                .qml_file("qml/Main.qml")
                .qml_file("qml/CheckmarkMenuItem.qml")
                .qml_file("qml/TypingCursorVisibility.qml")
                .qml_file("qml/ExpressionTypingRouter.qml")
                .qml_file("qml/AccentContrast.qml")
                .qml_file("qml/UndoShortcuts.qml")
                .qml_file("qml/ClearShortcuts.qml")
                .qml_file("qml/ProgrammerKeyRules.qml")
                .qml_file("qml/ProgrammerBasePreview.qml")
                .qml_file("qml/ProgrammerBaseShortcuts.qml")
                .qml_file("qml/ProgrammerKeySet.qml")
                .qml_file("qml/ProgrammerBitPanel.qml")
                .qml_file("qml/ProgrammerControlRow.qml")
                .qml_file("qml/ProgrammerHistoryDrawer.qml")
                .qml_file("qml/CalculatorKey.qml")
                .qml_file("qml/RootNotation.qml")
                .qml_file("qml/AdvancedKeySet.qml"),
        )
        .qrc("resources.qrc")
        .cc_builder(|compiler| {
            compiler.include("src");
            compiler.file("src/app_icon.cpp");
            compiler.flag_if_supported("-Wno-sfinae-incomplete");
        })
        .files(["src/backend.rs", "src/app_icon.rs"])
        .build();
    }
}
