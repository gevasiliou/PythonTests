/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* Define to 1 when help documentation is built */
#define ENABLE_HELP_DOC 1

/* Define to 1 to enable deletion of old partitions before creating a loop
   table workaround */
/* #undef ENABLE_LOOP_DELETE_OLD_PTNS_WORKAROUND */

/* always defined to indicate that i18n is enabled */
#define ENABLE_NLS 1

/* Define to 1 if online resize is enabled */
#define ENABLE_ONLINE_RESIZE 1

/* Define to 1 to enable partition re-read workaround */
/* #undef ENABLE_PT_REREAD_WORKAROUND */

/* description */
#define GETTEXT_PACKAGE "gparted"

/* Define to 1 if you have the `bind_textdomain_codeset' function. */
#define HAVE_BIND_TEXTDOMAIN_CODESET 1

/* define if the compiler supports basic C++11 syntax */
/* #undef HAVE_CXX11 */

/* Define to 1 if you have the `dcgettext' function. */
#define HAVE_DCGETTEXT 1

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define if the GNU gettext() function is already present or preinstalled. */
#define HAVE_GETTEXT 1

/* Define to 1 if gtkmm provides Gtk::MessageDialog::get_message_area()
   method. */
#define HAVE_GET_MESSAGE_AREA 1

/* Define to 1 if glibmm provides Glib::Regex class. */
#define HAVE_GLIB_REGEX 1

/* Define to 1 if gtkmm provides gtk_show_uri() function. */
#define HAVE_GTK_SHOW_URI 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define if your <locale.h> file defines LC_MESSAGES. */
#define HAVE_LC_MESSAGES 1

/* Define to 1 if you have the `dl' library (-ldl). */
#define HAVE_LIBDL 1

/* Define to 1 if you have the `parted' library (-lparted). */
#define HAVE_LIBPARTED 1

/* Define to 1 if have libparted fs resize capability */
#define HAVE_LIBPARTED_FS_RESIZE 1

/* Define to 1 if you have the `uuid' library (-luuid). */
#define HAVE_LIBUUID 1

/* Define to 1 if you have the <locale.h> header file. */
#define HAVE_LOCALE_H 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if gtkmm-2.4 provides Gtk::Window::set_default_icon_name()
   method. */
#define HAVE_SET_DEFAULT_ICON_NAME 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* Name of package */
#define PACKAGE "gparted"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "https://bugzilla.gnome.org/enter_bug.cgi?product=gparted"

/* Define to the full name of this package. */
#define PACKAGE_NAME "gparted"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "gparted 0.25.0"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "gparted"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "0.25.0"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Define to 1 to use native libparted /dev/mapper dmraid support */
#define USE_LIBPARTED_DMRAID 1

/* Define to 1 to use libparted large sector support */
#define USE_LIBPARTED_LARGE_SECTOR_SUPPORT 1

/* Version number of package */
#define VERSION "0.25.0"
