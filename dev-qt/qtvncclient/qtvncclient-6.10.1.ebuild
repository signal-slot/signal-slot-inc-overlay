# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Qt module for VNC client functionality"
HOMEPAGE="https://github.com/signal-slot/QtVncClient"
SRC_URI="https://github.com/signal-slot/QtVncClient/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/QtVncClient-${PV}"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+zlib"

DEPEND="
	dev-qt/qtbase:6[gui,network,widgets]
	zlib? ( sys-libs/zlib )
"
RDEPEND="${DEPEND}"
