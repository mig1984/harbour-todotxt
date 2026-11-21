Name:       harbour-todotxt
Summary:    Todo.txt task list for Sailfish OS (Simpletask port)
Version:    1.7.3
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
The best todo app for Sailfish OS - inspired by Simpletask, ADHD friendly and
built to keep form-filling to a minimum.
Todo.txt task manager following the Simpletask (Android) feature set:
priorities, contexts, projects, due and threshold dates, recurrence,
filters, multi-key sorting, saved filters, archiving to done.txt and
manual ordering with #N tokens.

# This description section includes metadata for SailfishOS:Chum, see
# https://github.com/sailfishos-chum/main/blob/main/Metadata.md
%if 0%{?_chum}
Title: Todo.txt
Type: desktop-application
DeveloperName: Jan Molič
Categories:
 - Office
 - Utility
Custom:
  Repo: https://github.com/mig1984/harbour-todotxt
PackageIcon: https://github.com/mig1984/harbour-todotxt/raw/main/icons/172x172/harbour-todotxt.png
Screenshots:
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-tasks.png
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-calendar.png
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-add-tasks.png
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-search.png
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-filter.png
 - https://github.com/mig1984/harbour-todotxt/raw/main/docs/screenshot-sort.png
Links:
  Homepage: https://github.com/mig1984/harbour-todotxt
  Bugtracker: https://github.com/mig1984/harbour-todotxt/issues
%endif

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
* Sat Nov 21 2026 Jan Molič <jan.molic@1984.cz> - 1.7.3-1
- Chum metadata (AppStream-style) in the spec description for the SailfishOS:Chum GUI

* Sat Nov 21 2026 Jan Molič <jan.molic@1984.cz> - 1.7.2-1
- Drag & drop: pressing the drag handle no longer nudges the list (it only starts moving once the finger actually moves)
- Drag & drop: fixed the target row flickering back and forth when dragging a one-line task onto a multi-line one
* Sat Nov 21 2026 Jan Molič <jan.molic@1984.cz> - 1.7.1-1
- Task editor: the keyboard stays open when a list/tag/priority suggestion is tapped, and the suggestion is appended at the end of the line with the cursor kept in place
- Quick choice now offers Today and the next seven days, labelled with weekday names that follow the current day
- Drag & drop: fixed the runaway auto-scroll and the back-and-forth flapping at the boundary between two tasks; smoother edge auto-scroll
- The list jumps to today (or the nearest due date) after clearing the filter
- Default sort now places priority above the #N position
* Fri Nov 20 2026 Jan Molič <jan.molic@1984.cz> - 1.7.0-1
- Recurring tasks: a new Settings slider sets how many occurrences to show into the future and the past (default 5, 0 = only the task), replacing the fixed 12-month horizon
- Recurring occurrences are shown around today (bounded by the creation date) so the list and calendar are no longer flooded with a year of repetitions
- The task editor is multi-line while editing too: press Enter to add another task, prefilled from the current line (a line added below the edited ones becomes a new task)
- Lists, tags and priority rows show a swipeable strip of quick suggestions (most used items over the last 60 days); tapping a chip adds it, tapping the row opens the full picker
* Thu Nov 19 2026 Jan Molič <jan.molic@1984.cz> - 1.6.3-1
- Selection mode now ends automatically when the last selected task is deselected (the bottom panel and the red header band close)
- The bottom selection panel gained a button that opens the tags (+projects) picker
- Removed the Complete button from the bottom selection panel; tasks are marked done by tapping their check circle
* Thu Nov 19 2026 Jan Molič <jan.molic@1984.cz> - 1.6.2-1
- The calendar in the due/threshold date picker now marks the due/threshold dates of every task in the file, not only the ones matching the active filter (the jump calendar from the header still follows the filter)
* Thu Nov 19 2026 Jan Molič <jan.molic@1984.cz> - 1.6.1-1
- Saved filters are now listed on the Filter page (below the filter sections): tap to apply, long press to update/rename/delete. The separate Saved filters page and its menu entry were removed, as was Sort order from the Filter page menu
- Open the filter by tapping the header title; the filter icon was removed from the header (the header now shows the calendar on the left, search next to it, and the clear button next to the title)
- A new task is prefilled from the active filter: all selected contexts and projects (and a single priority) are inserted into the new task
* Thu Nov 19 2026 Jan Molič <jan.molic@1984.cz> - 1.6.0-1
- Recurring tasks are now a series anchored on the due date (or the creation date when there is no due date): the occurrences are shown from the creation date into the future (horizon in Settings, default 12 months, 0 = off) and ticking one stores a done:YYYY-MM-DD marker instead of completing the task, so it is clear which occurrences are done
- A recurring task needs a due date or a creation date; the editor warns and blocks saving otherwise. Recurrence is edited from a new Recurrence row in the task editor (preset buttons with the active one highlighted, plus a custom count / unit / strict + editor)
- The due/threshold picker now shows the month calendar inline with the presets below it
- Dates are shown as a weekday and the date (e.g. st 2026-11-18); a threshold is a yellow chip (and a yellow calendar day, except today which is always green); the creation date is no longer shown as x days ago
- Task editor: a Quick choice section whose buttons set the due date and save; the calendar month title is now in the nominative (e.g. kveten 2026)
* Wed Nov 18 2026 Jan Molič <jan.molic@1984.cz> - 1.5.2-1
- Dates are shown as "<weekday> yyyy-MM-dd" (e.g. "st 2026-11-19") in the list, section headers and the editor; the creation date is no longer shown as "x days ago" and due dates no longer carry a label
- Threshold dates are always shown as a yellow chip (except completed tasks); in the calendar a threshold day is yellow (today is always green) and days whose tasks are all completed are no longer highlighted
- Due/threshold page now shows the month calendar inline (the separate date picker is gone), with quick buttons below and a Today reset button
- Task editor: quick Today/Tomorrow due buttons, moved to the bottom
- New tasks no longer get a creation date by default
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
