# x86_64 (amd64) の環境を強制
FROM --platform=linux/amd64 ubuntu:latest

RUN apt-get update && apt-get install -y \
    nasm build-essential binutils file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
CMD ["/bin/bash"]

