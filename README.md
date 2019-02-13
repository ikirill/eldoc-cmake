`eldoc-cmake` shows documentation (using `eldoc-mode`) when editing
CMake files.

To install:
```
(use-package eldoc-cmake
  :commands eldoc-cmake-enable
  :config
  (add-hook 'cmake-mode-hook #'eldoc-cmake-enable))
```
