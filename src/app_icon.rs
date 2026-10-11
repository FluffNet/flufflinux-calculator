#[cxx::bridge(namespace = "flufflinux")]
mod ffi {
    unsafe extern "C++" {
        include!("app_icon.h");
        fn set_application_icon();
        fn system_ui_languages() -> Vec<String>;
        fn translation_directories() -> Vec<String>;
        fn load_application_catalog(path: &str) -> bool;
        fn set_application_layout_direction(right_to_left: bool);
    }
}

pub fn set_application_icon() {
    ffi::set_application_icon();
}

pub fn install_application_translator() {
    let catalogs = crate::i18n::application_catalogs(ffi::system_ui_languages());
    let mut directories = ffi::translation_directories();
    // A previous installed version must not shadow the current embedded catalog.
    directories.insert(0, ":/com/flufflinux/calculator/translations".into());
    for catalog in catalogs {
        if catalog.name == "en" {
            ffi::set_application_layout_direction(false);
            return;
        }
        for directory in &directories {
            let path = format!("{directory}/flufflinux-calculator_{}.qm", catalog.name);
            if ffi::load_application_catalog(&path) {
                ffi::set_application_layout_direction(catalog.right_to_left);
                return;
            }
        }
    }
    ffi::set_application_layout_direction(false);
}
