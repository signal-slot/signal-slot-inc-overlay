# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="MCP server for GDB debugging"
HOMEPAGE="https://github.com/signal-slot/mcp-gdb"
EGIT_REPO_URI="https://github.com/signal-slot/mcp-gdb.git"

LICENSE="MIT"
SLOT="0"

RESTRICT="network-sandbox"

RDEPEND="
	dev-debug/gdb
	net-libs/nodejs
"
BDEPEND="
	net-libs/nodejs[npm]
"

src_compile() {
	npm install || die "npm install failed"
	npm run build || die "npm run build failed"
}

src_install() {
	local instdir="/usr/lib64/node_modules/${PN}"

	insinto "${instdir}"
	doins -r build node_modules package.json

	fperms +x "${instdir}/build/index.js"
	dosym "${instdir}/build/index.js" "/usr/bin/${PN}"
}
