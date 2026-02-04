# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Qt module for parsing and displaying Adobe PSD files"
HOMEPAGE="https://github.com/signal-slot/qtpsd"
EGIT_REPO_URI="https://github.com/signal-slot/qtpsd.git"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"

DEPEND="
	>=dev-qt/qtbase-6.8:6[gui]
"
RDEPEND="${DEPEND}"
