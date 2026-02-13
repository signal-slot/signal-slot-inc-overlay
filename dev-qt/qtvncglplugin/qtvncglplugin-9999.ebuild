# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Qt platform plugin for VNC with OpenGL support"
HOMEPAGE="https://github.com/signal-slot/qtvncglplugin"
EGIT_REPO_URI="https://github.com/signal-slot/qtvncglplugin.git"

LICENSE="GPL-3"
SLOT="0"

DEPEND="
	dev-qt/qtbase:6[gui,network,opengl]
	media-libs/libglvnd
"
RDEPEND="${DEPEND}"
