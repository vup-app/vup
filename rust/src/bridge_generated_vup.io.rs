use super::*;
// Section: wire functions

#[no_mangle]
pub extern "C" fn wire_encrypt_file_xchacha20(
    port_: i64,
    input_file_path: *mut wire_uint_8_list,
    output_file_path: *mut wire_uint_8_list,
    padding: usize,
) {
    wire_encrypt_file_xchacha20_impl(port_, input_file_path, output_file_path, padding)
}

#[no_mangle]
pub extern "C" fn wire_decrypt_file_xchacha20(
    port_: i64,
    input_file_path: *mut wire_uint_8_list,
    output_file_path: *mut wire_uint_8_list,
    key: *mut wire_uint_8_list,
    padding: usize,
    last_chunk_index: u32,
) {
    wire_decrypt_file_xchacha20_impl(
        port_,
        input_file_path,
        output_file_path,
        key,
        padding,
        last_chunk_index,
    )
}

#[no_mangle]
pub extern "C" fn wire_generate_thumbnail_for_image_file(
    port_: i64,
    image_type: *mut wire_uint_8_list,
    path: *mut wire_uint_8_list,
    exif_image_orientation: u8,
) {
    wire_generate_thumbnail_for_image_file_impl(port_, image_type, path, exif_image_orientation)
}

// Section: allocate functions

#[no_mangle]
pub extern "C" fn new_uint_8_list_1(len: i32) -> *mut wire_uint_8_list {
    let ans = wire_uint_8_list {
        ptr: support::new_leak_vec_ptr(Default::default(), len),
        len,
    };
    support::new_leak_box_ptr(ans)
}

// Section: related functions

// Section: impl Wire2Api

impl Wire2Api<String> for *mut wire_uint_8_list {
    fn wire2api(self) -> String {
        let vec: Vec<u8> = self.wire2api();
        String::from_utf8_lossy(&vec).into_owned()
    }
}

impl Wire2Api<Vec<u8>> for *mut wire_uint_8_list {
    fn wire2api(self) -> Vec<u8> {
        unsafe {
            let wrap = support::box_from_leak_ptr(self);
            support::vec_from_leak_ptr(wrap.ptr, wrap.len)
        }
    }
}

// Section: wire structs

#[repr(C)]
#[derive(Clone)]
pub struct wire_uint_8_list {
    ptr: *mut u8,
    len: i32,
}

// Section: impl NewWithNullPtr

pub trait NewWithNullPtr {
    fn new_with_null_ptr() -> Self;
}

impl<T> NewWithNullPtr for *mut T {
    fn new_with_null_ptr() -> Self {
        std::ptr::null_mut()
    }
}
