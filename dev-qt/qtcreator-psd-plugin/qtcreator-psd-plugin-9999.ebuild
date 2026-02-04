# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Qt Creator plugin for PSD file viewing"
HOMEPAGE="https://github.com/signal-slot/qtcreator-psd-plugin"
EGIT_REPO_URI="https://github.com/signal-slot/qtcreator-psd-plugin.git"

LICENSE="LGPL-3 GPL-2 GPL-3"
SLOT="0"

DEPEND="
	dev-qt/qt-creator
	dev-qt/qtpsd
"
RDEPEND="${DEPEND}"
