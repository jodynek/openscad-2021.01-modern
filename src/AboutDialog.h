#pragma once

#include "version.h"
#include "qtgettext.h"
#include "ui_AboutDialog.h"
#include <QString>
#include <QSysInfo>
#ifdef ENABLE_CGAL
#include <CGAL/version.h>
#endif

class AboutDialog : public QDialog, public Ui::AboutDialog
{
	Q_OBJECT;
public:
	AboutDialog(QWidget *) {
		setupUi(this);
		this->setWindowTitle( QString(_("About OpenSCAD")) + " " + openscad_shortversionnumber.c_str());
		QString tmp = this->aboutText->toHtml();
		tmp.replace("__VERSION__", openscad_detailedversionnumber.c_str());
		tmp.replace("__BUILDINFO__", buildInfo());
		this->aboutText->setHtml(tmp);
	}

	// "compiled with MSVC 19.51 (Visual Studio 2026), Qt 6.10.3, CGAL 5.6.1, 64 bit, Nov 13 2026"
	static QString buildInfo() {
		QString compiler;
#if defined(_MSC_VER)
		const int major = _MSC_VER / 100, minor = _MSC_VER % 100;
		QString vs = (_MSC_VER >= 1950) ? "Visual Studio 2026" : (_MSC_VER >= 1930) ? "Visual Studio 2022" : "Visual Studio";
		compiler = QString("MSVC %1.%2 (%3)").arg(major).arg(minor, 2, 10, QChar('0')).arg(vs);
#elif defined(__clang__)
		compiler = QString("Clang %1.%2").arg(__clang_major__).arg(__clang_minor__);
#elif defined(__GNUC__)
		compiler = QString("GCC %1.%2").arg(__GNUC__).arg(__GNUC_MINOR__);
#else
		compiler = "unknown compiler";
#endif
		QString info = QString("compiled with %1, Qt %2").arg(compiler, qVersion());
#ifdef CGAL_VERSION_MAJOR
		info += QString(", CGAL %1.%2.%3").arg(CGAL_VERSION_MAJOR).arg(CGAL_VERSION_MINOR).arg(CGAL_VERSION_PATCH);
#endif
		info += QString(", %1 bit, %2").arg(sizeof(void *) * 8).arg(__DATE__);
		return info;
	}

public slots:
        void on_okPushButton_clicked() { accept(); }
};
