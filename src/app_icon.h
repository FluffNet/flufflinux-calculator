#pragma once

#include "rust/cxx.h"

namespace flufflinux {

void set_application_icon();
rust::Vec<rust::String> system_ui_languages();
rust::Vec<rust::String> translation_directories();
bool load_application_catalog(rust::Str path);
void set_application_layout_direction(bool right_to_left);

}
