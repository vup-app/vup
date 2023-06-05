use image::imageops::FilterType;

use std::fs::File;
use std::io::{BufReader, Cursor, Read, Write};

use chacha20poly1305::{
    aead::{generic_array::GenericArray, Aead, KeyInit, OsRng},
    XChaCha20Poly1305, XNonce,
};

pub struct ThumbnailResponse {
    pub bytes: Vec<u8>,
    pub thumbhash_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

pub fn encrypt_file_xchacha20(
    input_file_path: String,
    output_file_path: String,
    padding: usize,
) -> anyhow::Result<Vec<u8>> {
    let input = File::open(input_file_path)?;
    let reader = BufReader::new(input);

    let output = File::create(output_file_path)?;

    let res = encrypt_file_xchacha20_internal(reader, output, padding);

    Ok(res.unwrap())
}

fn encrypt_file_xchacha20_internal<R: Read>(
    mut reader: R,
    mut output_file: File,
    padding: usize,
) -> anyhow::Result<Vec<u8>> {
    let key = XChaCha20Poly1305::generate_key(&mut OsRng);
    let cipher = XChaCha20Poly1305::new(&key);

    let mut chunk_index: u32 = 0;

    let chunk_size = 262144;

    let mut buffer = [0u8; 262144];

    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }

        /* if count < chunk_size {
            println!("last chunk");
        } else {
            println!("normal chunk");
        } */

        let length = if count < chunk_size {
            count + padding
        } else {
            count
        };

        let mut nonce = XNonce::default();

        let mut foo = [0u8; 24];
        for (place, data) in foo.iter_mut().zip(chunk_index.to_le_bytes().iter()) {
            *place = *data
        }

        nonce.copy_from_slice(&foo);

        let ciphertext = cipher.encrypt(&nonce, &buffer[..length]);

        output_file.write(&ciphertext.unwrap()).unwrap();
        chunk_index = chunk_index + 1;
    }

    output_file.flush().unwrap();

    Ok(key.to_vec())
}

pub fn decrypt_file_xchacha20(
    input_file_path: String,
    output_file_path: String,
    key: Vec<u8>,
    padding: usize,
    last_chunk_index: u32,
) -> anyhow::Result<u8> {
    let input = File::open(input_file_path)?;
    let reader = BufReader::new(input);

    let output = File::create(output_file_path)?;

    let res = decrypt_file_xchacha20_internal(reader, output, key, padding, last_chunk_index);

    Ok(res.unwrap())
}

fn decrypt_file_xchacha20_internal<R: Read>(
    mut reader: R,
    mut output_file: File,
    key: Vec<u8>,
    padding: usize,
    last_chunk_index: u32,
) -> anyhow::Result<u8> {
    let cipher = XChaCha20Poly1305::new(GenericArray::from_slice(&key));

    let mut chunk_index: u32 = 0;

    let mut buffer = [0u8; 262160];

    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }

        let mut nonce = XNonce::default();

        let mut foo = [0u8; 24];
        for (place, data) in foo.iter_mut().zip(chunk_index.to_le_bytes().iter()) {
            *place = *data
        }

        nonce.copy_from_slice(&foo);

        let ciphertext = cipher.decrypt(&nonce, &buffer[..count]);

        if chunk_index == last_chunk_index {
            output_file
                .write(&ciphertext.unwrap()[..(count - 16 - padding)])
                .unwrap();
        } else {
            output_file.write(&ciphertext.unwrap()).unwrap();
        }

        chunk_index = chunk_index + 1;
    }

    output_file.flush().unwrap();

    Ok(1)
}

pub fn generate_thumbnail_for_image_file(
    image_type: String,
    path: String,
    exif_image_orientation: u8,
) -> anyhow::Result<ThumbnailResponse> {
    // let img = image::open(path).unwrap();

    let input = File::open(path)?;
    let reader = BufReader::new(input);

    let img = image::io::Reader::new(reader)
        .with_guessed_format()?
        .decode()?;

    let mut width: u32 = img.width();
    let mut height: u32 = img.height();

    // TODO Maybe reduce thumbnail size
    // TODO Maybe reduce webp quality
    // TODO Maybe use other FilterType
    let mut scaled = if width > height {
        img.resize(1024, 384, FilterType::Triangle)
    } else if width < height {
        img.resize(384, 1024, FilterType::Triangle)
    } else {
        img.resize(384, 384, FilterType::Triangle)
    };

    if image_type == "audio" {
        if scaled.height() > scaled.width() {
            height = width;
            let diff = scaled.height() - scaled.width();
            scaled = scaled.crop(0, diff / 2, scaled.width(), scaled.width())
        } else if scaled.height() < scaled.width() {
            width = height;
            let diff = scaled.width() - scaled.height();
            scaled = scaled.crop(diff / 2, 0, scaled.height(), scaled.height())
        }
    }

    scaled = match &exif_image_orientation {
        2 => scaled.fliph(),
        3 => scaled.rotate180(),
        4 => scaled.rotate180().fliph(),
        5 => scaled.rotate90().fliph(),
        6 => scaled.rotate90(),
        7 => scaled.rotate270().fliph(),
        8 => scaled.rotate270(),
        _ => scaled,
    };

    // image::ImageOutputFormat::Jpeg(80)
    let mut bytes: Vec<u8> = Vec::new();
    scaled.write_to(&mut Cursor::new(&mut bytes), image::ImageOutputFormat::WebP)?;

    // TODO Maybe reduce height and width here
    let thumbhash_input_image = scaled.resize(100, 100, FilterType::Triangle);

    let thumbhash_bytes = thumbhash::rgba_to_thumb_hash(
        thumbhash_input_image.width().try_into().unwrap(),
        thumbhash_input_image.height().try_into().unwrap(),
        &thumbhash_input_image.to_rgba8().into_raw(),
    );

    Ok(ThumbnailResponse {
        bytes: bytes,
        width: width,
        height: height,
        thumbhash_bytes: thumbhash_bytes,
    })
}