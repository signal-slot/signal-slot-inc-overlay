# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo git-r3

DESCRIPTION="MCP server for screenshot capture"
HOMEPAGE="https://github.com/signal-slot/mcp-screenshot"
EGIT_REPO_URI="https://github.com/signal-slot/mcp-screenshot.git"

LICENSE="MIT"
SLOT="0"
IUSE="+desktop kms http"

DEPEND="
	desktop? (
		x11-libs/libxcb
		x11-libs/libXrandr
		sys-apps/dbus
		media-video/pipewire
		dev-libs/wayland
	)
	kms? ( x11-libs/libdrm )
"
RDEPEND="${DEPEND}"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_configure() {
	local myfeatures=()
	use desktop && myfeatures+=( desktop )
	use kms && myfeatures+=( kms )
	use http && myfeatures+=( http )
	cargo_src_configure --no-default-features
}
