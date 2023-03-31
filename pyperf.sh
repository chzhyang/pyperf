python3 -m pyperformance run \
    --inherit-environ http_proxy,https_proxy \
    --affinity 2,114 \
    -r \
    -p ./static-modules-python3.11.2/python \
    -o pidigits.json \
    -b pidigits