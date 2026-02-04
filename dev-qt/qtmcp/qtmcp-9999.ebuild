# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Qt-based Model Context Protocol (MCP) implementation"
HOMEPAGE="https://github.com/signal-slot/QtMcp"
EGIT_REPO_URI="https://github.com/signal-slot/QtMcp.git"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"
IUSE="gui network widgets"

DEPEND="
	>=dev-qt/qtbase-6.8.1:6
	gui? ( >=dev-qt/qtbase-6.8.1:6[gui] )
	network? ( >=dev-qt/qtbase-6.8.1:6[network] )
	widgets? ( >=dev-qt/qtbase-6.8.1:6[widgets] )
"
RDEPEND="${DEPEND}"
