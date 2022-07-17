'use strict'


let availableDirectoryFiles = {};

let chunkCache = {};

let downloadingChunkLock = {};

// ! --- WARNING ---
// This is a proof of concept, the code quality isn't very good
// ! --- WARNING ---

// ~ redsolver

let skynetPortal = location.protocol + '//' + location.hostname.split('.').slice(-2).join('.');

if (skynetPortal === 'http://localhost') {
  skynetPortal = 'https://siasky.net'
}
console.log('using portal', skynetPortal)

importScripts('/__skyfs_internal_EWhqPkTLE2L3jv_sodium.js')

function _base64ToUint8Array(base64) {
  var binary_string = atob(base64);
  var len = binary_string.length;
  var bytes = new Uint8Array(len);
  for (var i = 0; i < len; i++) {
    bytes[i] = binary_string.charCodeAt(i);
  }
  return bytes;
}

function openRead(df, start, totalSize) {
  return new ReadableStream({
    async start(controller) {

      console.log('skynetPortal', skynetPortal);

      console.log('using openRead ', start, totalSize);

      let chunk = Math.floor(start / df.file.chunkSize);

      let offset = start % df.file.chunkSize;

      let url = skynetPortal + '/' + df.file.url.substr(6);



      const secretKey =
        _base64ToUint8Array(df.file.key.replace(/-/g, '+')
          .replace(/_/g, '/'));


      const totalEncSize =
        (Math.floor(df.file.size / df.file.chunkSize) * (df.file.chunkSize + 16)) +
        (df.file.size % df.file.chunkSize) +
        16 +
        df.file.padding;

      console.log('totalEncSize', totalEncSize);

      let downloadedEncData = new Uint8Array();

      let isDone = false;

      let servedBytes = start;

      while (start < totalSize) {
        // console.log('chunkCache', chunkCache);
        let chunkLockKey = df.file.hash + '-' + chunk.toString();


        if (chunkCache[chunkLockKey] === undefined) {
          // console.log('downloadingChunkLock', downloadingChunkLock)
          if (downloadingChunkLock[chunkLockKey] !== undefined) {
            console.log('[chunk] wait ' + chunk);
            // sub?.cancel();
            await downloadingChunkLock[chunkLockKey];
          } else {
            let complete;
            let err;
            const completer = new Promise((onFulfilled, onRejected) => {
              complete = onFulfilled; err = onRejected;
            })
            // TODO 
            downloadingChunkLock[chunkLockKey] = completer;

            let retryCount = 0;

            while (true) {
              try {
                console.log('[chunk] dl ' + chunk);
                let encChunkSize = (df.file.chunkSize + 16);
                let encStartByte = chunk * encChunkSize;

                let end = Math.min(encStartByte + encChunkSize - 1, totalEncSize - 1);

                let hasDownloadError = false;

                if (downloadedEncData.length == 0) {
                  console.log('[chunk] send http range request');

                  const res = await fetch(url, {
                    credentials: "include",
                    headers: {
                      'range': 'bytes=' + encStartByte + '-',
                    }
                  });

                  let maxMemorySize = (32 * (df.file.chunkSize + 16));


                  const reader = res.body.getReader();

                  function push() {
                    reader.read().then(
                      ({ done, value }) => {
                        // ! Stop request when too fast
                        if (downloadedEncData.length > maxMemorySize) {
                          // controller.close();
                          reader.cancel();
                          downloadedEncData = downloadedEncData.slice(0, maxMemorySize);

                          return;
                        }
                        if (done) {
                          isDone = true;
                          return;
                        }
                        let mergedArray = new Uint8Array(downloadedEncData.length + value.length);
                        mergedArray.set(downloadedEncData);
                        mergedArray.set(value, downloadedEncData.length);

                        downloadedEncData = mergedArray;
                        // console.log('addencdata', done, value);

                        push();
                      },
                    );
                  }
                  push();


                  // lateFuture =
                  // console.log('continue');
                }
                let isLastChunk = (end + 1) === totalEncSize;

                if (isLastChunk) {
                  while (!isDone) {
                    // console.log('loop2', downloadedEncData.length)
                    if (hasDownloadError) throw 'Download HTTP request failed';
                    await new Promise(r => setTimeout(r, 10));

                  }
                } else {
                  while (downloadedEncData.length < (df.file.chunkSize + 16)) {
                    // console.log('loop', downloadedEncData.length, (df.file.chunkSize + 16))
                    if (hasDownloadError) throw 'Download HTTP request failed';
                    await new Promise(r => setTimeout(r, 10));

                  }
                }
                // console.log('bytes', bytes);

                let bytes =
                  isLastChunk
                    ? downloadedEncData
                    : downloadedEncData.slice(0, (df.file.chunkSize + 16));

                // console.log('bytes', bytes);

                if (isLastChunk) {
                  downloadedEncData = new Uint8Array();
                } else {
                  downloadedEncData = downloadedEncData.slice(df.file.chunkSize + 16);
                }

                function numberToArrayBuffer(value) {
                  const view = new DataView(new ArrayBuffer(sodium.crypto_secretbox_NONCEBYTES))
                  for (var index = (sodium.crypto_secretbox_NONCEBYTES - 1); index >= 0; --index) {
                    view.setUint8(sodium.crypto_secretbox_NONCEBYTES - 1 - index, value % 256)
                    value = value >> 8;
                  }
                  return view.buffer
                }

                let nonce = new Uint8Array(numberToArrayBuffer(chunk));

                // console.log(await bytes.arrayBuffer(), nonce, secretKey)


                let r = sodium.crypto_secretbox_open_easy(bytes, nonce, secretKey);


                if (isLastChunk) {
                  chunkCache[chunkLockKey] =
                    new Blob([r.slice(
                      0,
                      r.length - df.file.padding,
                    )]);
                } else {
                  chunkCache[chunkLockKey] = new Blob([r]);
                }
                complete();
                break;
              } catch (e) {
                console.error(e);
                retryCount++;
                if (retryCount > 10) {
                  complete();
                  delete downloadingChunkLock[chunkLockKey];
                  throw new Error('Too many retries. ($e)' + e);
                }

                downloadedEncData = new Uint8Array();

                console.error('[chunk] download error for chunk ' + chunk + ' (try #' + retryCount + ')');
                await new Promise(r => setTimeout(r, 1000));
              }
            }
          }
        } else {
          // sub?.cancel();
        }
        console.log('[chunk] serve ' + chunk);

        const chunkCacheBlob = chunkCache[chunkLockKey];

        start += chunkCacheBlob.size - offset;

        if (start > totalSize) {
          let end = chunkCacheBlob.size - (start - totalSize);
          console.log('[chunk] LIMIT to ' + end);


          // Get the data and send it to the browser via the controller
          controller.enqueue(new Uint8Array(await chunkCacheBlob.slice(offset, end).arrayBuffer()));
          /* yield * chunkCacheFile.openRead(
            offset,
            end,
          ); */
        } else {
          // console.log('just serve', chunkCacheBlob, offset)
          if (offset === 0) {
            // console.log('array2', chunkCacheBlob);
            let array = new Uint8Array(await chunkCacheBlob.arrayBuffer());
            // console.log('array2', array);
            controller.enqueue(array);
          } else {
            controller.enqueue(new Uint8Array(await chunkCacheBlob.slice(offset).arrayBuffer()));
          }
          // console.log('write success');
          /* yield * chunkCacheFile.openRead(
            offset,
          ); */
        }

        offset = 0;
        // servedBytes+=offset

        chunk++;

      }

      console.log('write done chunk:', chunk, downloadedEncData);

      controller.close();
    }
  });
}


async function respond(url, req) {

  let directoryFile = availableDirectoryFiles[url.pathname];

  const resOpt = {
    headers: {
      'Content-Type': directoryFile.mimeType || 'text/plain',
    },
  }


  var start = 0;
  var totalSize = directoryFile.file.size;

  const range = req.headers.get('range')

  if (range) {
    const m = range.match(/bytes=(\d+)-(\d*)/)
    if (m) {
      const size = directoryFile.file.size
      const begin = +m[1]
      const end = +m[2] || size

      start = begin;
      totalSize = end;

      resOpt.status = 206
      resOpt.headers['content-range'] = `bytes ${begin}-${end - 1}/${size}`
    }
  }

  resOpt.headers['content-length'] = directoryFile.file.size - start - (directoryFile.file.size - totalSize)
  return new Response(openRead(directoryFile, start, totalSize), resOpt)
}

onfetch = (e) => {

  const req = e.request
  const url = new URL(req.url)

  if (url.origin !== location.origin) {
    return
  }
  if (availableDirectoryFiles[url.pathname] === undefined) {
    return
  }

  if (url.pathname.startsWith('__skyfs_internal_EWhqPkTLE2L3jv_')) {
    return
  }

  console.log('pathname', url.pathname);

  e.respondWith(respond(url, req))
}

onmessage = (e) => {
  console.log('onmessage', e);

  const path = e.data['path'];
  const directoryFile = e.data['file'];

  if (e.data['ciphertext'] !== undefined) {
    console.log(e.data);

    const secretKey =
      _base64ToUint8Array(e.data['key'].replace(/-/g, '+')
        .replace(/_/g, '/'));

    const ciphertext =
      _base64ToUint8Array(e.data['ciphertext'].replace(/-/g, '+')
        .replace(/_/g, '/'));


    let bytes = sodium.crypto_secretbox_open_easy(ciphertext, new Uint8Array(24), secretKey);

    console.log(bytes);
    availableDirectoryFiles = JSON.parse(new TextDecoder().decode(bytes));
    availableDirectoryFiles['/'] = availableDirectoryFiles['/index.html'];
    availableDirectoryFiles[''] = availableDirectoryFiles['/index.html'];

    e.source.postMessage({ 'success': true })

  } else {
    if (availableDirectoryFiles[path] === undefined) {
      availableDirectoryFiles[path] = directoryFile;
      e.source.postMessage({ 'success': true })
    }
  }


}

onactivate = () => {
  clients.claim()
}