# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="MCP server for Qt Help documentation"
HOMEPAGE="https://github.com/signal-slot/mcp-qthelp"
EGIT_REPO_URI="https://github.com/signal-slot/mcp-qthelp.git"

LICENSE="BSD"
SLOT="0"

DEPEND="
	dev-qt/qtbase:6[gui]
	dev-qt/qt-tools:6[assistant]
	dev-qt/qtmcp
"
RDEPEND="${DEPEND}"
