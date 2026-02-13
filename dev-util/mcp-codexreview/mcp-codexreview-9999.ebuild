# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="MCP server that runs OpenAI Codex CLI to review git changes"
HOMEPAGE="https://github.com/signal-slot/mcp-codexreview"
EGIT_REPO_URI="https://github.com/signal-slot/mcp-codexreview.git"

LICENSE="MIT"
SLOT="0"

RESTRICT="network-sandbox"

RDEPEND="
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
