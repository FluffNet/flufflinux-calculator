#[cxx::bridge(namespace = "flufflinux")]
mod ffi {
    unsafe extern "C++" {
        include!("app_icon.h");
        fn set_application_icon();
        fn install_application_translator();
    }
}

pub fn set_application_icon() {
    ffi::set_application_icon();
}

pub fn install_application_translator() {
    ffi::install_application_translator();
}
