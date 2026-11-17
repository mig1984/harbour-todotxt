Name:       harbour-todotxt
Summary:    Todo.txt task list for Sailfish OS (Simpletask port)
Version:    1.2.0
Release:    1
License:    GPLv3
URL:        https://github.com/mig1984/harbour-todotxt
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils
BuildRequires:  qt5-qttools-linguist

%description
Todo.txt task manager following the Simpletask (Android) feature set:
priorities, contexts, projects, due and threshold dates, recurrence,
filters, multi-key sorting, saved filters, archiving to done.txt and
manual ordering with #N tokens.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install
desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%license LICENSE
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%changelog
* Mon Nov 16 2026 Jan Molič <jan.molic@1984.cz> - 1.1.0-1
- Sort order: all keys listed, active keys reorderable by drag&drop and
  direction flip, inactive keys can be added/removed; entry in main menu
- Default sort: completed, due date, manual #N, ..., alphabetical last
- Filter: clear button per section (lists, tags, priorities)
- Undo bar when completing/uncompleting a task
- Header: jump to today's task (or nearest due), clear filter button
* Mon Nov 16 2026 Jan Molič <jan.molic@1984.cz> - 1.0.0-1
- First public release: Simpletask feature set (priorities, contexts, projects,
  due/threshold dates, recurrence, filters, multi-key sort, saved filters,
  archiving, manual #N ordering), 10 UI languages

* Sun Nov 15 2026 Jan Molič <jan.molic@1984.cz> - 0.1.0-1
- Initial port of Simpletask to Sailfish OS
