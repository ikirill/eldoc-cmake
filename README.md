`eldoc-cmake` shows documentation (using `eldoc-mode`) when editing
CMake files.

To install:
```
(use-package eldoc-cmake
  :hook (cmake-mode . eldoc-cmake-enable))
```

What it looks like:
![screenshot.png](screenshot.png)
