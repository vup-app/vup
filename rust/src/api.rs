use chacha20poly1305::{
    aead::{generic_array::GenericArray, Aead, KeyInit, OsRng},
    XChaCha20Poly1305, XNonce,
};

use blake3::Hash;

use flutter_rust_bridge::{support::from_vec_to_array, SyncReturn};
use std::fs::File;
use std::io::{BufReader, Cursor, Read, Seek, SeekFrom, Write};

use image::imageops::FilterType;

pub struct ThumbnailResponse {
    pub bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

pub fn encrypt_file_xchacha20(
    input_file_path: String,
    output_file_path: String,
    padding: usize,
) -> Result<Vec<u8>, anyhow::Error> {
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
) -> Result<Vec<u8>, anyhow::Error> {
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
) -> Result<u8, anyhow::Error> {
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
) -> Result<u8, anyhow::Error> {
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
) -> Result<ThumbnailResponse, anyhow::Error> {
    // let img = image::open(path).unwrap();

    let input = File::open(path)?;
    let reader = BufReader::new(input);

    let img = image::io::Reader::new(reader)
        .with_guessed_format()?
        .decode()?;

    // TODO test resize
    /* final thumbnail = type == 'audio'
    ? img.copyResizeCropSquare(image, size)
    : image.width > image.height
         */

    let mut scaled = img.resize(512, 512, FilterType::Triangle);

    if image_type == "audio" {
        if scaled.height() > scaled.width() {
            let diff = scaled.height() - scaled.width();
            scaled = scaled.crop(0, diff / 2, scaled.width(), scaled.width())
        } else if img.height() < img.width() {
            let diff = scaled.width() - scaled.height();
            scaled = scaled.crop(diff / 2, 0, scaled.height(), scaled.height())
        }
        // img.crop(x, y, width, height)
    }

    // image::ImageOutputFormat::Jpeg(80)
    let mut bytes: Vec<u8> = Vec::new();
    scaled.write_to(&mut Cursor::new(&mut bytes), image::ImageOutputFormat::WebP)?;

    Ok(ThumbnailResponse {
        bytes: bytes,
        width: img.width(),
        height: img.height(),
    })
}

/* fn sha1_digest<R: Read>(mut reader: R) -> Result<Vec<u8>, anyhow::Error> {
    let mut hasher = Sha1::new();

    let mut buffer = [0; 1048576];

    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }

    let hash = hasher.finalize();
    Ok(hash[..].to_vec())
}

pub fn hash_sha1_file(path: String) -> Result<Vec<u8>, anyhow::Error> {
    let input = File::open(path)?;
    let reader = BufReader::new(input);
    let digest = sha1_digest(reader)?;

    Ok(digest)
} */

/* pub fn encrypt_chunk(key: Vec<u8>, nonce: Vec<u8>, bytes: Vec<u8>) -> ZeroCopyBuffer<Vec<u8>> {
    // TODO Try XChaCha20Poly1305

    // let key = ChaCha20Poly1305::new_from_slice(&key);

    let cipher = ChaCha20Poly1305::new_from_slice(&key).unwrap();

    let mut nonceObj = Nonce::default();
    // nonceObj.copy_from_slice(&nonce);
    nonceObj.clone_from_slice(&nonce);

    let ciphertext = cipher.encrypt(&nonceObj, &bytes[..]);
    // let plaintext = cipher.decrypt(&nonce, ciphertext.as_ref())?;
    // assert_eq!(&plaintext, b"plaintext message");

    ZeroCopyBuffer(ciphertext.unwrap())
} */

// ! everything below this is copied from s5-server

pub fn encrypt_xchacha20poly1305(
    key: Vec<u8>,
    nonce: Vec<u8>,
    plaintext: Vec<u8>,
) -> Result<Vec<u8>, anyhow::Error> {
    let cipher = XChaCha20Poly1305::new(GenericArray::from_slice(&key));
    let xnonce = XNonce::from_slice(&nonce);
    let ciphertext = cipher.encrypt(&xnonce, &plaintext[..]);
    Ok(ciphertext.unwrap())
}

pub fn decrypt_xchacha20poly1305(
    key: Vec<u8>,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
) -> Result<Vec<u8>, anyhow::Error> {
    let cipher = XChaCha20Poly1305::new(GenericArray::from_slice(&key));
    let xnonce = XNonce::from_slice(&nonce);

    let plaintext = cipher.decrypt(&xnonce, &ciphertext[..]);
    Ok(plaintext.unwrap())
}

fn blake3_digest<R: Read>(mut reader: R) -> Result<Hash, anyhow::Error> {
    let mut hasher = blake3::Hasher::new();

    let mut buffer = [0; 1048576];

    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }

    Ok(hasher.finalize())
}

pub fn hash_blake3_file(path: String) -> Result<Vec<u8>, anyhow::Error> {
    let input = File::open(path)?;
    let reader = BufReader::new(input);
    let digest = blake3_digest(reader)?;

    Ok(digest.as_bytes().to_vec())
}

pub fn hash_blake3(input: Vec<u8>) -> Result<Vec<u8>, anyhow::Error> {
    let digest = blake3::hash(&input);
    Ok(digest.as_bytes().to_vec())
}

pub fn hash_blake3_sync(input: Vec<u8>) -> SyncReturn<Vec<u8>> {
    let digest = blake3::hash(&input);
    SyncReturn(digest.as_bytes().to_vec())
}

pub fn verify_integrity(
    chunk_bytes: Vec<u8>,
    offset: u64,
    bao_outboard_bytes: Vec<u8>,
    blake3_hash: Vec<u8>,
) -> Result<u8, anyhow::Error> {
    let mut slice_stream = bao::encode::SliceExtractor::new_outboard(
        FakeSeeker::new(&chunk_bytes[..]),
        Cursor::new(&bao_outboard_bytes),
        offset,
        262144,
    );

    let mut decode_stream = bao::decode::SliceDecoder::new(
        &mut slice_stream,
        &bao::Hash::from(from_vec_to_array(blake3_hash)),
        offset,
        262144,
    );
    let mut decoded = Vec::new();
    decode_stream.read_to_end(&mut decoded)?;

    Ok(1)
}

struct FakeSeeker<R: Read> {
    reader: R,
    bytes_read: u64,
}

impl<R: Read> FakeSeeker<R> {
    fn new(reader: R) -> Self {
        Self {
            reader,
            bytes_read: 0,
        }
    }
}

impl<R: Read> Read for FakeSeeker<R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.reader.read(buf)?;
        self.bytes_read += n as u64;
        Ok(n)
    }
}

impl<R: Read> Seek for FakeSeeker<R> {
    fn seek(&mut self, _: SeekFrom) -> std::io::Result<u64> {
        // Do nothing and return the current position.
        Ok(self.bytes_read)
    }
}

pub fn hash_bao_file(path: String) -> Result<BaoResult, anyhow::Error> {
    let input = File::open(path)?;
    let reader = BufReader::new(input);

    let result = hash_bao_file_internal(reader);

    Ok(result.unwrap())
}

pub fn hash_bao_memory(bytes: Vec<u8>) -> Result<BaoResult, anyhow::Error> {
    let result = hash_bao_file_internal(&bytes[..]);

    Ok(result.unwrap())
}

pub struct BaoResult {
    pub hash: Vec<u8>,
    pub outboard: Vec<u8>,
}

fn hash_bao_file_internal<R: Read>(mut reader: R) -> Result<BaoResult, anyhow::Error> {
    let mut encoded_incrementally = Vec::new();

    let encoded_cursor = std::io::Cursor::new(&mut encoded_incrementally);

    let mut encoder = bao::encode::Encoder::new_outboard(encoded_cursor);

    let mut buffer = [0; 262144];

    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        let _res = encoder.write(&buffer[..count]);
    }

    Ok(BaoResult {
        hash: encoder.finalize()?.as_bytes().to_vec(),
        outboard: encoded_incrementally,
    })
}
