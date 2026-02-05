# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="MCP server for VNC remote control"
HOMEPAGE="https://github.com/signal-slot/mcp-vnc"
EGIT_REPO_URI="https://github.com/signal-slot/mcp-vnc.git"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"

DEPEND="
	dev-qt/qtbase:6[gui,network,widgets]
	dev-qt/qtvncclient
	dev-qt/qtmcp
"
RDEPEND="${DEPEND}"
