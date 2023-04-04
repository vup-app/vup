#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
typedef struct _Dart_Handle* Dart_Handle;

typedef struct DartCObject DartCObject;

typedef int64_t DartPort;

typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);

typedef struct wire_uint_8_list {
  uint8_t *ptr;
  int32_t len;
} wire_uint_8_list;

typedef struct DartCObject *WireSyncReturn;

void store_dart_post_cobject(DartPostCObjectFnType ptr);

Dart_Handle get_dart_object(uintptr_t ptr);

void drop_dart_object(uintptr_t ptr);

uintptr_t new_dart_opaque(Dart_Handle handle);

intptr_t init_frb_dart_api_dl(void *obj);

void wire_encrypt_file_xchacha20(int64_t port_,
                                 struct wire_uint_8_list *input_file_path,
                                 struct wire_uint_8_list *output_file_path,
                                 uintptr_t padding);

void wire_decrypt_file_xchacha20(int64_t port_,
                                 struct wire_uint_8_list *input_file_path,
                                 struct wire_uint_8_list *output_file_path,
                                 struct wire_uint_8_list *key,
                                 uintptr_t padding,
                                 uint32_t last_chunk_index);

void wire_generate_thumbnail_for_image_file(int64_t port_,
                                            struct wire_uint_8_list *image_type,
                                            struct wire_uint_8_list *path,
                                            uint8_t exif_image_orientation);

void wire_encrypt_xchacha20poly1305(int64_t port_,
                                    struct wire_uint_8_list *key,
                                    struct wire_uint_8_list *nonce,
                                    struct wire_uint_8_list *plaintext);

void wire_decrypt_xchacha20poly1305(int64_t port_,
                                    struct wire_uint_8_list *key,
                                    struct wire_uint_8_list *nonce,
                                    struct wire_uint_8_list *ciphertext);

void wire_hash_blake3_file(int64_t port_, struct wire_uint_8_list *path);

void wire_hash_blake3(int64_t port_, struct wire_uint_8_list *input);

WireSyncReturn wire_hash_blake3_sync(struct wire_uint_8_list *input);

void wire_verify_integrity(int64_t port_,
                           struct wire_uint_8_list *chunk_bytes,
                           uint64_t offset,
                           struct wire_uint_8_list *bao_outboard_bytes,
                           struct wire_uint_8_list *blake3_hash);

void wire_hash_bao_file(int64_t port_, struct wire_uint_8_list *path);

void wire_hash_bao_memory(int64_t port_, struct wire_uint_8_list *bytes);

struct wire_uint_8_list *new_uint_8_list_0(int32_t len);

void free_WireSyncReturn(WireSyncReturn ptr);

static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) wire_encrypt_file_xchacha20);
    dummy_var ^= ((int64_t) (void*) wire_decrypt_file_xchacha20);
    dummy_var ^= ((int64_t) (void*) wire_generate_thumbnail_for_image_file);
    dummy_var ^= ((int64_t) (void*) wire_encrypt_xchacha20poly1305);
    dummy_var ^= ((int64_t) (void*) wire_decrypt_xchacha20poly1305);
    dummy_var ^= ((int64_t) (void*) wire_hash_blake3_file);
    dummy_var ^= ((int64_t) (void*) wire_hash_blake3);
    dummy_var ^= ((int64_t) (void*) wire_hash_blake3_sync);
    dummy_var ^= ((int64_t) (void*) wire_verify_integrity);
    dummy_var ^= ((int64_t) (void*) wire_hash_bao_file);
    dummy_var ^= ((int64_t) (void*) wire_hash_bao_memory);
    dummy_var ^= ((int64_t) (void*) new_uint_8_list_0);
    dummy_var ^= ((int64_t) (void*) free_WireSyncReturn);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    dummy_var ^= ((int64_t) (void*) get_dart_object);
    dummy_var ^= ((int64_t) (void*) drop_dart_object);
    dummy_var ^= ((int64_t) (void*) new_dart_opaque);
    return dummy_var;
}