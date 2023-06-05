use blake3::Hash;

use chacha20poly1305::{
    aead::{generic_array::GenericArray, Aead, KeyInit},
    XChaCha20Poly1305, XNonce,
};
use flutter_rust_bridge::{support::from_vec_to_array, SyncReturn};
use std::fs::File;
use std::io::{BufReader, Cursor, Read, Seek, SeekFrom, Write};

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

pub fn encrypt_xchacha20poly1305(
    key: Vec<u8>,
    nonce: Vec<u8>,
    plaintext: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    let cipher = XChaCha20Poly1305::new(GenericArray::from_slice(&key));
    let xnonce = XNonce::from_slice(&nonce);
    let ciphertext = cipher.encrypt(&xnonce, &plaintext[..]);
    Ok(ciphertext.unwrap())
}

pub fn decrypt_xchacha20poly1305(
    key: Vec<u8>,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    let cipher = XChaCha20Poly1305::new(GenericArray::from_slice(&key));
    let xnonce = XNonce::from_slice(&nonce);

    let plaintext = cipher.decrypt(&xnonce, &ciphertext[..]);
    Ok(plaintext.unwrap())
}

fn blake3_digest<R: Read>(mut reader: R) -> anyhow::Result<Hash> {
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

pub fn hash_blake3_file(path: String) -> anyhow::Result<Vec<u8>> {
    let input = File::open(path)?;
    let reader = BufReader::new(input);
    let digest = blake3_digest(reader)?;

    Ok(digest.as_bytes().to_vec())
}

pub fn hash_blake3(input: Vec<u8>) -> anyhow::Result<Vec<u8>> {
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
) -> anyhow::Result<u8> {
    let mut slice_stream = abao::encode::SliceExtractor::new_outboard(
        FakeSeeker::new(&chunk_bytes[..]),
        Cursor::new(&bao_outboard_bytes),
        offset,
        262144,
    );

    let mut decode_stream = abao::decode::SliceDecoder::new(
        &mut slice_stream,
        &abao::Hash::from(from_vec_to_array(blake3_hash)),
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

pub fn hash_bao_file(path: String) -> anyhow::Result<BaoResult> {
    let input = File::open(path)?;
    let reader = BufReader::new(input);

    let result = hash_bao_file_internal(reader);

    Ok(result.unwrap())
}

pub fn hash_bao_memory(bytes: Vec<u8>) -> anyhow::Result<BaoResult> {
    let result = hash_bao_file_internal(&bytes[..]);

    Ok(result.unwrap())
}

pub struct BaoResult {
    pub hash: Vec<u8>,
    pub outboard: Vec<u8>,
}

fn hash_bao_file_internal<R: Read>(mut reader: R) -> anyhow::Result<BaoResult> {
    let mut encoded_incrementally = Vec::new();

    let encoded_cursor = std::io::Cursor::new(&mut encoded_incrementally);

    let mut encoder = abao::encode::Encoder::new_outboard(encoded_cursor);

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
