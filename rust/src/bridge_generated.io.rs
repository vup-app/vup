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
) {
    wire_generate_thumbnail_for_image_file_impl(port_, image_type, path)
}

#[no_mangle]
pub extern "C" fn wire_encrypt_xchacha20poly1305(
    port_: i64,
    key: *mut wire_uint_8_list,
    nonce: *mut wire_uint_8_list,
    plaintext: *mut wire_uint_8_list,
) {
    wire_encrypt_xchacha20poly1305_impl(port_, key, nonce, plaintext)
}

#[no_mangle]
pub extern "C" fn wire_decrypt_xchacha20poly1305(
    port_: i64,
    key: *mut wire_uint_8_list,
    nonce: *mut wire_uint_8_list,
    ciphertext: *mut wire_uint_8_list,
) {
    wire_decrypt_xchacha20poly1305_impl(port_, key, nonce, ciphertext)
}

#[no_mangle]
pub extern "C" fn wire_hash_blake3_file(port_: i64, path: *mut wire_uint_8_list) {
    wire_hash_blake3_file_impl(port_, path)
}

#[no_mangle]
pub extern "C" fn wire_hash_blake3(port_: i64, input: *mut wire_uint_8_list) {
    wire_hash_blake3_impl(port_, input)
}

#[no_mangle]
pub extern "C" fn wire_hash_blake3_sync(input: *mut wire_uint_8_list) -> support::WireSyncReturn {
    wire_hash_blake3_sync_impl(input)
}

#[no_mangle]
pub extern "C" fn wire_verify_integrity(
    port_: i64,
    chunk_bytes: *mut wire_uint_8_list,
    offset: u64,
    bao_outboard_bytes: *mut wire_uint_8_list,
    blake3_hash: *mut wire_uint_8_list,
) {
    wire_verify_integrity_impl(port_, chunk_bytes, offset, bao_outboard_bytes, blake3_hash)
}

#[no_mangle]
pub extern "C" fn wire_hash_bao_file(port_: i64, path: *mut wire_uint_8_list) {
    wire_hash_bao_file_impl(port_, path)
}

#[no_mangle]
pub extern "C" fn wire_hash_bao_memory(port_: i64, bytes: *mut wire_uint_8_list) {
    wire_hash_bao_memory_impl(port_, bytes)
}

// Section: allocate functions

#[no_mangle]
pub extern "C" fn new_uint_8_list_0(len: i32) -> *mut wire_uint_8_list {
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

// Section: sync execution mode utility

#[no_mangle]
pub extern "C" fn free_WireSyncReturn(ptr: support::WireSyncReturn) {
    unsafe {
        let _ = support::box_from_leak_ptr(ptr);
    };
}
