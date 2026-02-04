# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Qt module for parsing and displaying Adobe PSD files"
HOMEPAGE="https://github.com/signal-slot/qtpsd"
SRC_URI="https://github.com/signal-slot/qtpsd/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${PV}"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	>=dev-qt/qtbase-6.8:6[gui]
"
RDEPEND="${DEPEND}"
