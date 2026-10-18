#!/bin/sh
# Generates the Swift for Protos/link_bridge.proto: messages, the server (here) and, with --client <dir>, a client for
# an app. Needs protoc; builds protoc-gen-swift and protoc-gen-grpc-swift from the resolved packages.
set -e
cd "$(dirname "$0")/.."
swift package resolve >/dev/null
TOOLS=.build/generators
mkdir -p "$TOOLS"
if [ ! -x "$TOOLS/protoc-gen-swift" ]; then
    swift build -c release --package-path .build/checkouts/swift-protobuf --product protoc-gen-swift
    cp .build/checkouts/swift-protobuf/.build/release/protoc-gen-swift "$TOOLS/"
fi
if [ ! -x "$TOOLS/protoc-gen-grpc-swift" ]; then
    swift build -c release --package-path .build/checkouts/grpc-swift --product protoc-gen-grpc-swift
    cp .build/checkouts/grpc-swift/.build/release/protoc-gen-grpc-swift "$TOOLS/"
fi

generate() { # out-dir, server, client
    protoc Protos/link_bridge.proto --proto_path=Protos \
        --plugin=protoc-gen-swift="$TOOLS/protoc-gen-swift" --swift_out="$1" --swift_opt=Visibility=Public \
        --plugin=protoc-gen-grpc-swift="$TOOLS/protoc-gen-grpc-swift" --grpc-swift_out="$1" \
        --grpc-swift_opt=Visibility=Public,Server=$2,Client=$3
}

generate Sources/LinkBridgeProtocol true false
if [ "$1" = "--client" ] && [ -n "$2" ]; then
    mkdir -p "$2"
    generate "$2" false true
    cp Protos/link_bridge.proto "$2/"
fi
