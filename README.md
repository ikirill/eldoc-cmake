`eldoc-cmake` shows documentation (using `eldoc-mode`) when editing
CMake files.

To install:
```
(use-package eldoc-cmake
  :commands eldoc-cmake-eldoc-documentation-function
  :config
  (add-hook 'cmake-mode-hook
    (lambda ()
      (setq-local eldoc-documentation-function
                  #'eldoc-cmake-eldoc-documentation-function))))
```
