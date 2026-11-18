Name:       harbour-todotxt
Summary:    Todo.txt task list for Sailfish OS (Simpletask port)
Version:    1.5.1
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
* Wed Nov 18 2026 Jan Molič <jan.molic@1984.cz> - 1.5.1-1
- Task long-press now enters multi-selection with the pressed task selected, instead of opening a context menu
- Links, phone numbers and e-mail addresses in a task can now be opened/called/mailed from the edit form
- First start: a hint over the example list explains it and points to Settings for choosing the folder
* Wed Nov 18 2026 Jan Molič <jan.molic@1984.cz> - 1.5.0-1
- On first start, if no folder has been chosen yet, an example todo.txt and done.txt are created in ~/Documents/todotxt so the app opens with a usable list (tasks overdue, due today, tomorrow, the day after tomorrow and in a week, plus one completed)
- Existing files are never overwritten; pick another folder in Settings
* Wed Nov 18 2026 Jan Molič <jan.molic@1984.cz> - 1.4.1-1
- Cover: tasks due or thresholded on today, tomorrow or the day after tomorrow are shown first (overdue only fills the remaining slots; completed tasks are no longer shown)
- Selection mode: the header is highlighted to match the selected task check circles
* Wed Nov 18 2026 Jan Molič <jan.molic@1984.cz> - 1.4.0-1
- Incremental task list updates: the list is no longer reset and redrawn on every change, so the scroll position and any running undo bars are kept, and several tasks can be completed at once
- Date menu and task long-press menu: add a quick "Day after tomorrow" due action
- Date menu: move "No date" next to "Pick a date"; the Czech label is now "Bez datumu"
* Tue Nov 17 2026 Jan Molič <jan.molic@1984.cz> - 1.3.1-1
- Fix: the task list jumped back to the top after completing a task (with a
  filter active) or after dragging a task into a lower due-date group; the
  scroll position is now kept across such data changes (filter/sort changes
  still start at the top)
* Tue Nov 17 2026 Jan Molič <jan.molic@1984.cz> - 1.3.0-1
- Fix: the task long-press menu's priority, due date and threshold date
  actions had no effect (the Component-based context menu was destroyed on
  close, tearing down the page signal connections); the menu is now inline
- Task long-press menu: remove Complete/Mark incomplete (use the checkbox)
- Task long-press menu: add a quick "Tomorrow" due-date action
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
