require 'marcel'
require 'marcel/mime_type'

Marcel::MimeType.extend "application/x-tar", extensions: %w[gem]
Marcel::MimeType.extend "application/x-x509-ca-cert", extensions: %w[cert]
Marcel::MimeType.extend "image/svg+xml-compressed", parents: "application/gzip", extensions: %w[svgz]
Marcel::MimeType.extend "application/x-tarz", parents: "application/x-compress", extensions: %w[taz]
Marcel::MimeType.extend "application/x-lzma-compressed-tar", parents: "application/x-lzma", extensions: %w[tlz]
Marcel::MimeType.extend "application/zstd", extensions: %w[zst]
