docker build -f Dockerfile -t builder .

docker run --rm --init -v C:\Users\Michael\Documents\GitHub\Cyberselves\mini-decoder.js/output:/opt/output builder