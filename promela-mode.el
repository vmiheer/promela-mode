;;; promela-mode.el --- major mode for editing PROMELA program files

;; Author: Eric Engstrom <eric.engstrom@honeywell.com>
;; Maintainer: Eric Engstrom
;; Package-Requires: ((emacs "25"))
;; Version: 1.111
;; Some patches by: Rudi Schlatte <rudi@constantly.at>
;; Keywords: languages, spin, promela, tools

;; Copyright (C) 1998-2003  Eric Engstrom / Honeywell Laboratories

;; ... Possibly insert GPL here someday ...

;;; Commentary:

;;	This file contains code for a GNU Emacs major mode for editing
;;	PROMELA (SPIN) program files.

;;	Type "C-h m" in Emacs (while in a buffer in promela-mode) for
;;	information on how to configure indentation and fontification,
;;	or look at the configuration variables below.

;;	To use, place promela-mode.el in a directory in your load-path.
;;	Then, put the following lines into your .emacs and promela-mode
;;	will be automatically loaded when editing a PROMELA program.

;;	(autoload 'promela-mode "promela-mode" "PROMELA mode" nil t)
;;	(setq auto-mode-alist
;;	      (append
;;	       (list (cons "\\.promela$"  'promela-mode)
;;		     (cons "\\.spin$"     'promela-mode)
;;		     (cons "\\.pml$"      'promela-mode)
;;		     ;; (cons "\\.other-extensions$"     'promela-mode)
;;	       	     )
;;	       auto-mode-alist))

;;	If you wish for promela-mode to be used for files with other
;;	extensions you add your own patterned after the code above.

;;      Note that promela-mode adhears to the font-lock "standards" and
;;      defines several "levels" of fontification or colorization.  The
;;      default is fairly gaudy, so I can imagine that some folks would
;;      like a bit less.  FMI: see `font-lock-maximum-decoration'

;; This mode was known to work under the following versions of emacs:
;;   - XEmacs:        19.16, 20.x, 21.x
;;   - FSF/GNU Emacs: 19.34
;;   - NTEmacs (FSF): 20.[67]
;; The current version was patched by rudi@constantly.at to work on GNU
;; Emacs 25.  No known incompatibilities were introduced, but you never know ...

;; §note: adapt to emacs 24. Retrocopmatibity have not being test, but
;; according changes made, nothing might have been broken
;;

;; Please send any comments, bugs, patches or other requests to
;; Eric Engstrom at engstrom@htc.honeywell.com

;; To-Do:
;;  - compile/syntax-check/verify? (suggested by R.Goldman)
;;  - indentation - splitting lines at logical operators (M. Rangarajan)
;;    [ This might "devolve" to indentation after "->" or ";" 
;;      being as is, but anything else indent even more? ]
;;       :: SomeReallyLongArrayRef[this].typedefField != SomeReallyLongConstant -> /* some-comment */
;;    [ Suggestion would be to break the first line after the !=, therefore: ]
;;       :: SomeReallyLongArrayRef[this].typedefField 
;;	      != SomeReallyLongConstant -> /* some-comment */
;;    [ at this point I'm not so sure about this change... EE: 2001/05/19 ] 

;;; -------------------------------------------------------------------------

(require 'custom)
(require 'newcomment)

;;; Code:

;; NOTE: folowing 1.11 cvs version
(defconst promela-mode-version "Revision: 1.111"
  "Promela-mode version number.")

;; -------------------------------------------------------------------------
;; The following constant values can be modified by the user in a .emacs file

(defgroup promela nil
  "Editing Promela files, the input language of the Spin model checker."
  :group 'languages)

(defcustom promela-block-indent 2
  "Controls indentation of lines within a block (`{') construct"
  :type 'integer
  :group 'promela)
(put 'promela-block-indent 'safe-local-variable 'integerp)

(defcustom promela-selection-indent 2
  "Controls indentation of options within a selection (`if')
or iteration (`do') construct"
  :type 'integer
  :group 'promela)
(put 'promela-selection-indent 'safe-local-variable 'integerp)

(defcustom promela-selection-option-indent 3
  "Controls indentation of lines after options within selection or
iteration construct (`::')"
  :type 'integer
  :group 'promela)
(put 'promela-selection-option-indent 'safe-local-variable 'integerp)

(defcustom promela-comment-col comment-column
  "Defines the desired comment column for comments to the right of text."
  :type 'integer
  :group 'promela)
(put 'promela-comment-col 'safe-local-variable 'integerp)

(defcustom promela-tab-always-indent t
  "Non-nil means TAB in Promela mode should always reindent the current line,
regardless of where in the line point is when the TAB command is used."
  :type 'boolean
  :group 'promela)

(defcustom promela-auto-match-delimiter t
  "Non-nil means typing an open-delimiter (i.e. parentheses, brace, quote, etc)
should also insert the matching closing delmiter character."
  :type 'boolean
  :group 'promela)

;; That should be about it for most users...
;; unless you wanna hack elisp, the rest of this is probably uninteresting


;; -------------------------------------------------------------------------
;; help determine what emacs we have here...

(defconst promela-xemacsp (string-match "XEmacs" (emacs-version))
  "Non-nil if we are running in the XEmacs environment.")

;;;(defconst promela-xemacs20p (and promela-xemacsp (>= emacs-major-version 20))
;;  "Non-nil if we are running in an XEmacs environment version 20 or greater.")

;; -------------------------------------------------------------------------
;; promela-mode font faces/definitions

;; make use of font-lock stuff, so say that explicitly
(require 'font-lock)

;; BLECH!  YUCK!   I just wish these guys could agree to something....
;; Faces available in:         ntemacs emacs  xemacs xemacs xemacs    
;;     font-lock- xxx -face     20.6   19.34  19.16   20.x   21.x
;;       -builtin-                X                             
;;       -constant-               X                             
;;       -comment-                X      X      X      X      X
;;       -doc-string-                           X      X      X
;;       -function-name-          X      X      X      X      X
;;       -keyword-                X      X      X      X      X
;;       -preprocessor-                         X      X      X
;;       -reference-                     X      X      X      X
;;       -signal-name-                          X      X!20.0 
;;       -string-                 X      X      X      X      X
;;       -type-                   X      X      X      X      X
;;       -variable-name-          X      X      X      X      X
;;       -warning-                X                           X

;;; Compatibility on faces between versions of emacs-en
(unless promela-xemacsp

  (defvar font-lock-preprocessor-face 'font-lock-preprocessor-face
    "Face name to use for preprocessor statements.")
  ;; For consistency try to define the preprocessor face == builtin face
  (condition-case nil
      (copy-face 'font-lock-builtin-face 'font-lock-preprocessor-face)
    (error
     (defface font-lock-preprocessor-face
       '((t (:foreground "blue" :italic nil :underline t)))
       "Face Lock mode face used to highlight preprocessor statements."
       :group 'font-lock-highlighting-faces)))
  
  (defvar font-lock-reference-face 'font-lock-reference-face
    "Face name to use for constants and reference and label names.")
  ;; For consistency try to define the reference face == constant face
  (condition-case nil
      (copy-face 'font-lock-constant-face 'font-lock-reference-face)
    (error
     (defface font-lock-reference-face
       '((((class grayscale) (background light))
          (:foreground "LightGray" :bold t :underline t))
         (((class grayscale) (background dark))
          (:foreground "Gray50" :bold t :underline t))
         (((class color) (background light)) (:foreground "CadetBlue"))
         (((class color) (background dark)) (:foreground "Aquamarine"))
         (t (:bold t :underline t)))
       "Font Lock mode face used to highlight constancs, references and labels."
       :group 'font-lock-highlighting-faces)))

  )

;; send-poll "symbol" face is custom to promela-mode 
;; but check for existence to allow someone to override it
(defvar promela-fl-send-poll-face 'promela-fl-send-poll-face
  "Face name to use for Promela Send or Poll symbols: `!' or `?'")
(copy-face (if promela-xemacsp 'modeline 'region)
           'promela-fl-send-poll-face)

;; some emacs-en don't define or have regexp-opt available.  
(unless (functionp 'regexp-opt)
  (defmacro regexp-opt (strings)
    "Cheap imitation of `regexp-opt' since it's not availble in this emacs"
    `(mapconcat 'identity ,strings "\\|")))
  

;; -------------------------------------------------------------------------
;; promela-mode font lock specifications/regular-expressions
;;   - for help, look at definition of variable 'font-lock-keywords
;;   - some fontification ideas from -- [engstrom:20010309.1435CST]
;;	 Pat Tullman (tullmann@cs.utah.edu) and
;;	 Ny Aina Razermera Mamy (ainarazr@cs.uoregon.edu)
;;     both had promela-mode's that I discovered after starting this one...
;;     (but neither did any sort of indentation ;-)

(defvar promela-font-lock-keywords-1 nil
  "Subdued level highlighting for Promela mode.")

(defvar promela-font-lock-keywords-2 nil
  "Medium level highlighting for Promela mode.")

(defvar promela-font-lock-keywords-3 nil
  "Gaudy level highlighting for Promela mode.")

;; set each of those three variables now..
(let ((promela-keywords
       (eval-when-compile 
         (regexp-opt 
          '("active" "assert" "atomic" "break" "d_step"
            "do" "dproctype" "else" "empty" "enabled"
            "eval" "fi" "full" "goto" "hidden" "if" "init"
            "inline" "len" "local" "mtype" "nempty" "never"
            "nfull" "od" "of" "pcvalue" "printf" "priority"
            "proctype" "provided" "run" "show" "skip" 
            "timeout" "trace" "typedef" "unless" "xr" "xs"))))
      (promela-types
       (eval-when-compile
         (regexp-opt '("bit" "bool" "byte" "short"
                       "int" "unsigned" "chan")))))

  ;; really simple fontification (strings and comments come for "free")
  (setq promela-font-lock-keywords-1
    (list
     ;; Keywords:
     (cons (concat "\\<\\(" promela-keywords "\\)\\>")
           'font-lock-keyword-face)
     ;; Types:
     (cons (concat "\\<\\(" promela-types "\\)\\>")
           'font-lock-type-face)
     ;; Special constants:
     '("\\<_\\(np\\|pid\\|last\\)\\>" . font-lock-reference-face)))

  ;; more complex fontification
  ;; add function (proctype) names, lables and goto statements
  ;; also add send/receive/poll fontification
  (setq promela-font-lock-keywords-2
   (append promela-font-lock-keywords-1
    (list
     ;; ANY Pre-Processor directive (lazy method: any line beginning with "#[a-z]+")
     '("^\\(#[ \t]*[a-z]+\\)"		1 'font-lock-preprocessor-face t)

     ;; "Functions" (proctype-s and inline-s)
     (list (concat "\\<\\("
                   (eval-when-compile
                     (regexp-opt '("run" "dproctype" "proctype" "inline")))
                   "\\)\\>[ \t]*\\(\\sw+\\)?")
           ;;'(1 'font-lock-keyword-face nil)
           '(2 'font-lock-function-name-face nil t))

    ;; Labels and GOTO labels
    '("^\\(\\sw+\\):" 1 'font-lock-reference-face)
    '("\\<\\(goto\\)\\>[ \t]+\\(\\sw+\\)"
      ;;(1 'font-lock-keyword-face nil)
      (2 'font-lock-reference-face nil t))

    ;; Send, Receive and Poll
    '("\\(\\sw+\\)\\(\\[[^\\?!]+\\]\\)?\\(\\??\\?\\|!?!\\)\\(\\sw+\\)"
      (1 'font-lock-variable-name-face nil t)
      (3 'promela-fl-send-poll-face nil t)
      (4 'font-lock-reference-face nil t)
      )
    )))

  ;; most complex fontification
  ;; add pre-processor directives, typed variables and hidden/typedef decls.
  (setq promela-font-lock-keywords-3
   (append promela-font-lock-keywords-2
    (list
     ;; ANY Pre-Processor directive (lazy method: any line beginning with "#[a-z]+")
     ;;'("^\\(#[ \t]*[a-z]+\\)"		1 'font-lock-preprocessor-face t)
     ;; "defined" in an #if or #elif and associated macro names
     '("^#[ \t]*\\(el\\)?if\\>"
       ("\\<\\(defined\\)\\>[ \t]*(?\\(\\sw+\\)" nil nil
        (1 'font-lock-preprocessor-face nil t)
        (2 'font-lock-reference-face nil t)))
     '("^#[ \t]*ifn?def\\>"
       ("[ \t]*\\(\\sw+\\)" nil nil
        (1 'font-lock-reference-face nil t)))
     ;; Filenames in #include <...> directives
     '("^#[ \t]*include[ \t]+<\\([^>\"\n]+\\)>"	1 'font-lock-string-face nil t)
     ;; Defined functions and constants/types (non-functions)
     '("^#[ \t]*define[ \t]+"
       ("\\(\\sw+\\)(" 			nil nil (1 'font-lock-function-name-face nil t))
       ("\\(\\sw+\\)[ \t]+\\(\\sw+\\)"	nil nil (1 'font-lock-variable-name-face)
       						(2 'font-lock-reference-face nil t))
       ("\\(\\sw+\\)[^(]?"		nil nil (1 'font-lock-reference-face nil t)))

     ;; Types AND variables
     ;;   - room for improvement: (i.e. don't currently):
     ;;     highlight user-defined types and asociated variable declarations
     (list (concat "\\<\\(" promela-types "\\)\\>")
          ;;'(1 'font-lock-type-face)
          ;; now match the variables after the type definition, if any
          '(promela-match-variable-or-declaration
            nil nil
            (1 'font-lock-variable-name-face) ;; nil t)
            (2 font-lock-reference-face nil t)))
    
    ;; Typedef/hidden types and declarations
    '("\\<\\(typedef\\|hidden\\)\\>[ \t]*\\(\\sw+\\)?"
      ;;(1 'font-lock-keyword-face nil)
      (2 'font-lock-type-face nil t)
      ;; now match the variables after the type definition, if any
      (promela-match-variable-or-declaration
       nil nil
       (1 'font-lock-variable-name-face nil t)
       (2 'font-lock-reference-face nil t)))
    )))
  )

(defvar promela-font-lock-keywords promela-font-lock-keywords-3
  "Default expressions to highlight in Promela mode.")

;; Font-lock matcher functions:
(defun promela-match-variable-or-declaration (limit)
  "Match, and move over, any declaration/definition item after point.
Matches after point, but ignores leading whitespace characters.
Does not move further than LIMIT.

The expected syntax of a declaration/definition item is `word' (preceded
by optional whitespace) optionally followed by a `= value' (preceded and
followed by more optional whitespace)

Thus the regexp matches after point:	word [ = value ]
					^^^^     ^^^^^
Where the match subexpressions are:	  1        2

The item is delimited by (match-beginning 1) and (match-end 1).
If (match-beginning 2) is non-nil, the item is followed by a `value'."
  (when (looking-at "[ \t]*\\(\\sw+\\)[ \t]*=?[ \t]*\\(\\sw+\\)?[ \t]*,?")
    (goto-char (min limit (match-end 0)))))


;; -------------------------------------------------------------------------
;; "install" promela-mode font lock specifications

;; FMI: look up 'font-lock-defaults
(defconst promela-font-lock-defaults
  '(
    (promela-font-lock-keywords 
     promela-font-lock-keywords-1
     promela-font-lock-keywords-2
     promela-font-lock-keywords-3)		  ;; font-lock stuff (keywords)
    nil						  ;; keywords-only flag
    nil						  ;; case-fold keyword searching
    ;;((?_ . "w") (?$ . "."))			  ;; mods to syntax table
    nil						  ;; mods to syntax table (see below)
    nil						  ;; syntax-begin
    (font-lock-mark-block-function . mark-defun))
  )

;; "install" the font-lock-defaults based upon version of emacs we have
(cond (promela-xemacsp
       (put 'promela-mode 'font-lock-defaults promela-font-lock-defaults))
      ;; `font-lock-defaults-alist' was removed in Emacs 24 - for recent
      ;; emacsen, we set `font-lock-defaults' in `promela-mode' instead
      ((and (< emacs-major-version 24)
            (not (assq 'promela-mode font-lock-defaults-alist)))
       (setq font-lock-defaults-alist
	     (cons
	      (cons 'promela-mode promela-font-lock-defaults)
	      font-lock-defaults-alist))))


;; -------------------------------------------------------------------------
;; other promela-mode specific definitions

(defconst promela-defun-prompt-regexp
  "^[ \t]*\\(d?proctype\\|init\\|inline\\|never\\|trace\\|typedef\\|mtype\\s-+=\\)[^{]*"
  "Regexp describing the beginning of a Promela top-level definition.")

(defvar promela-mode-syntax-table (make-syntax-table)
  "Syntax table in use in PROMELA-mode buffers.")
(modify-syntax-entry ?\\ "\\"    promela-mode-syntax-table)
(modify-syntax-entry ?/  ". 124" promela-mode-syntax-table)
(modify-syntax-entry ?*  ". 23b" promela-mode-syntax-table)
(modify-syntax-entry ?\n  ">"    promela-mode-syntax-table)
(modify-syntax-entry ?\^m ">"    promela-mode-syntax-table)
(modify-syntax-entry ?+  "."     promela-mode-syntax-table)
(modify-syntax-entry ?-  "."     promela-mode-syntax-table)
(modify-syntax-entry ?=  "."     promela-mode-syntax-table)
(modify-syntax-entry ?%  "."     promela-mode-syntax-table)
(modify-syntax-entry ?<  "."     promela-mode-syntax-table)
(modify-syntax-entry ?>  "."     promela-mode-syntax-table)
(modify-syntax-entry ?&  "."     promela-mode-syntax-table)
(modify-syntax-entry ?|  "."     promela-mode-syntax-table)
(modify-syntax-entry ?.  "_"     promela-mode-syntax-table)
(modify-syntax-entry ?_  "w"     promela-mode-syntax-table)
(modify-syntax-entry ?\' "\""    promela-mode-syntax-table)

(defvar promela-mode-abbrev-table nil
  "*Abbrev table in use in promela-mode buffers.")
(if promela-mode-abbrev-table
    nil
  (define-abbrev-table 'promela-mode-abbrev-table
    '(
;; Commented out for now - need to think about what abbrevs make sense
;;     ("assert" 	"ASSERT" 	promela-check-expansion 0)
;;     ("d_step"	"D_STEP"	promela-check-expansion 0)
;;     ("break" 	"BREAK" 	promela-check-expansion 0)
;;     ("do" 		"DO" 		promela-check-expansion 0)
;;     ("proctype"	"PROCTYPE" 	promela-check-expansion 0)
      )))

(defvar promela-matching-delimiter-alist
  '( (?(  . ?))
     (?[  . ?])
     (?{  . "\n}")
     ;(?<  . ?>)
     (?\' . ?\')
     (?\` . ?\`)
     (?\" . ?\") )
  "List of pairs of matching open/close delimiters - for auto-insert")


;; -------------------------------------------------------------------------
;;;###autoload
(define-derived-mode promela-mode prog-mode "Promela"
  "Major mode for editing PROMELA code.
\\{promela-mode-map}

Variables controlling indentation style:
  promela-block-indent
	Relative offset of lines within a block (`{') construct.

  promela-selection-indent
  	Relative offset of option lines within a selection (`if')
	or iteration (`do') construct.

  promela-selection-option-indent
	Relative offset of lines after/within options (`::') within
 	selection or iteration constructs.

  promela-comment-col
	Defines the desired comment column for comments to the right of text.

  promela-tab-always-indent
	Non-nil means TAB in PROMELA mode should always reindent the current
	line, regardless of where in the line the point is when the TAB
	command is used.

  promela-auto-match-delimiter
	Non-nil means typing an open-delimiter (i.e. parentheses, brace,
        quote, etc) should also insert the matching closing delmiter
        character.

Turning on PROMELA mode runs the hooks in `promela-mode-hook'.

For example: '
	(add-hook 'promela-mode-hook '(lambda ()
			(setq promela-block-indent 2)
			(setq promela-selection-indent 0)
			(setq promela-selection-option-indent 2)
			(local-set-key \"\\C-m\" 'promela-indent-newline-indent)
			))'

will indent block two steps, will make selection options aligned with DO/IF
and sub-option lines indent to a column after the `::'.  Also, lines will
be reindented when you hit RETURN.

Note that promela-mode adhears to the font-lock \"standards\" and
defines several \"levels\" of fontification or colorization.  The
default is fairly gaudy, so if you would prefer a bit less, please see
the documentation for the variable: `font-lock-maximum-decoration'.
"
  :syntax-table promela-mode-syntax-table
  (define-key promela-mode-map "\t"		'promela-indent-command)
  (define-key promela-mode-map "\C-m"		'promela-newline-and-indent)
  ;;(define-key promela-mode-map 'backspace	'backward-delete-char-untabify)
  (define-key promela-mode-map "\C-c\C-p"	'promela-beginning-of-block)
  ;;(define-key promela-mode-map "\C-c\C-n"	'promela-end-of-block)
  (define-key promela-mode-map "\M-\C-a"	'promela-beginning-of-defun)
  ;;(define-key promela-mode-map "\M-\C-e"	'promela-end-of-defun)
  (define-key promela-mode-map "\C-c("		'promela-toggle-auto-match-delimiter)
  (define-key promela-mode-map "{"		'promela-open-delimiter)
  (define-key promela-mode-map "}" 		'promela-close-delimiter)
  (define-key promela-mode-map "("		'promela-open-delimiter)
  (define-key promela-mode-map ")" 		'promela-close-delimiter)
  (define-key promela-mode-map "["		'promela-open-delimiter)
  (define-key promela-mode-map "]" 		'promela-close-delimiter)
  (define-key promela-mode-map ";"		'promela-insert-and-indent)
  (define-key promela-mode-map ":"		'promela-insert-and-indent)
  ;; 
  ;; this is preliminary at best - use at your own risk:
  (define-key promela-mode-map "\C-c\C-s"	'promela-syntax-check)
  ;;
  ;;(define-key promela-mode-map "\C-c\C-d"	'promela-mode-toggle-debug)
  ;;(define-key promela-mode-map "\C-c\C-r"	'promela-mode-revert-buffer)
  (setq local-abbrev-table 	promela-mode-abbrev-table)

  ;; Make local variables
  (make-local-variable 'paragraph-start)
  (make-local-variable 'paragraph-separate)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (make-local-variable 'indent-line-function)
  (make-local-variable 'indent-region-function)
  (make-local-variable 'parse-sexp-ignore-comments)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-end)
  (make-local-variable 'comment-start-skip)
  (make-local-variable 'defun-prompt-regexp)
  (make-local-variable 'compile-command)
  ;; Now set their values
  (setq case-fold-search 		t
        paragraph-start 		(concat "^$\\|" page-delimiter)
        paragraph-separate 		paragraph-start
        paragraph-ignore-fill-prefix 	t
        indent-line-function 		'promela-indent-command
	;;indent-region-function 	'promela-indent-region
        parse-sexp-ignore-comments 	t
        comment-start 			"/* "
        comment-end 			" */"
        comment-column 			promela-comment-col
        comment-start-skip 		"\\(//+\\|/\\*+\\)\\s *"
        defun-prompt-regexp 		promela-defun-prompt-regexp)

  ;; Turn on font-lock mode
  (setq font-lock-defaults promela-font-lock-defaults))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.promela\\'" . promela-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.spin\\'" . promela-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.pml\\'" . promela-mode))


;; -------------------------------------------------------------------------
;; Interactive functions
;;

(defun promela-mode-version ()
  "Print the current version of promela-mode in the minibuffer"
  (interactive)
  (message (concat "Promela-Mode: " promela-mode-version)))

(defun promela-beginning-of-block ()
  "Move backward to start of containing block.
Containing block may be `{', `do' or `if' construct, or comment."
  (interactive)
  (goto-char (promela-find-start-of-containing-block-or-comment)))

(defun promela-beginning-of-defun (&optional arg)
  "Move backward to the beginning of a defun.
With argument, do it that many times.
Negative arg -N means move forward to Nth following beginning of defun.
Returns t unless search stops due to beginning or end of buffer.

See also 'beginning-of-defun.

This is a Promela-mode specific version since default (in xemacs 19.16 and
NT-Emacs 20) don't seem to skip comments - they will stop inside them.

Also, this makes sure that the beginning of the defun is actually the
line which starts the proctype/init/etc., not just the open-brace."
  (interactive "p")
  (beginning-of-defun arg)
  (if (not (looking-at promela-defun-prompt-regexp))
      (re-search-backward promela-defun-prompt-regexp nil t))
  (if (promela-inside-comment-p)
      (goto-char (promela-find-start-of-containing-comment))))

(defun promela-indent-command ()
  "Indent the current line as PROMELA code."
  (interactive)
  (if (and (not promela-tab-always-indent)
           (save-excursion
             (skip-chars-backward " \t")
             (not (bolp))))
      (tab-to-tab-stop)
    (promela-indent-line)))

(defun promela-newline-and-indent ()
  "Promela-mode specific newline-and-indent which expands abbrevs before
running a regular newline-and-indent."
  (interactive)
  (if abbrev-mode
      (expand-abbrev))
  (newline-and-indent))

(defun promela-indent-newline-indent ()
  "Promela-mode specific newline-and-indent which expands abbrevs and
indents the current line before running a regular newline-and-indent."
  (interactive)
  (save-excursion (promela-indent-command))
  (if abbrev-mode
      (expand-abbrev))
  (newline-and-indent))

(defun promela-insert-and-indent ()
  "Insert the last character typed and re-indent the current line"
  (interactive)
  (insert last-command-event)
  (save-excursion (promela-indent-command)))

(defun promela-open-delimiter ()
  "Inserts the open and matching close delimiters, indenting as appropriate."
  (interactive)
  (insert last-command-event)
  (if (and promela-auto-match-delimiter (not (promela-inside-comment-p)))
      (save-excursion
        (insert (cdr (assq last-command-event promela-matching-delimiter-alist)))
        (promela-indent-command))))

(defun promela-close-delimiter ()
  "Inserts and indents a close delimiter."
  (interactive)
  (insert last-command-event)
  (if (not (promela-inside-comment-p))
      (save-excursion (promela-indent-command))))

(defun promela-toggle-auto-match-delimiter ()
  "Toggle auto-insertion of parens and other delimiters.
See variable `promela-auto-insert-matching-delimiter'"
  (interactive)
  (setq promela-auto-match-delimiter
        (not promela-auto-match-delimiter))
  (message (concat "Promela auto-insert matching delimiters "
                   (if promela-auto-match-delimiter
                       "enabled" "disabled"))))


;; -------------------------------------------------------------------------
;; Compilation/Verification functions

;; all of this is in serious "beta" mode - don't trust it ;-)
(setq 
        promela-compile-command		"spin "
        promela-syntax-check-args	"-a -v "
)

;;(setq compilation-error-regexp-alist
;;      (append compilation-error-regexp-alist
;;              '(("spin: +line +\\([0-9]+\\) +\"\\([^\"]+\\)\"" 2 1))))

(defun promela-syntax-check ()
  (interactive)
  (compile (concat promela-compile-command
                   promela-syntax-check-args
                   (buffer-name))))


;; -------------------------------------------------------------------------
;; Indentation support functions

(defun promela-indent-around-label ()
  "Indent the current line as PROMELA code,
but make sure to consider the label at the beginning of the line."
  (beginning-of-line)
  (delete-horizontal-space)	; delete any leading whitespace
  (if (not (looking-at "\\sw+:\\([ \t]*\\)"))
      (error "promela-indent-around-label: no label on this line")
    (goto-char (match-beginning 1))
    (let* ((space  (length (match-string 1)))
           (indent (promela-calc-indent))
           (wanted (max 0 (- indent (current-column)))))
      (if (>= space wanted)
          (delete-region (point) (+ (point) (- space wanted)))
        (goto-char (+ (point) space))
        (indent-to-column indent)))))

;; Note that indentation is based ENTIRELY upon the indentation of the
;; previous line(s), esp. the previous non-blank line and the line
;; starting the current containgng block...
(defun promela-indent-line ()
  "Indent the current line as PROMELA code.
Return the amount the by which the indentation changed."
  (beginning-of-line)
  (if (looking-at "[ \t]*\\sw+:")
      (promela-indent-around-label)
    (let ((indent (promela-calc-indent))
          beg
          shift-amt
          (pos (- (point-max) (point))))
      (setq beg (point))
      (skip-chars-forward " \t")
      (setq shift-amt (- indent (current-column)))
      (if (zerop shift-amt)
          (if (> (- (point-max) pos) (point))
              (goto-char (- (point-max) pos)))
        (delete-region beg (point))
        (indent-to indent)
        (if (> (- (point-max) pos) (point))
            (goto-char (- (point-max) pos))))
      shift-amt)))

(defun promela-calc-indent ()
  "Return the appropriate indentation for this line as an int."
  (save-excursion
    (beginning-of-line)
    (let* ((orig-point  (point))
           (state       (promela-parse-partial-sexp))
           (paren-depth (nth 0 state))
           (paren-point (or (nth 1 state) 1))
           (paren-char  (char-after paren-point)))
      ;;(what-cursor-position)
      (cond
       ;; Indent not-at-all - inside a string
       ((nth 3 state)
        (current-indentation))
       ;; Indent inside a comment
       ((nth 4 state)
        (promela-calc-indent-within-comment))
       ;; looking at a pre-processor directive - indent=0
       ((looking-at "[ \t]*#\\(define\\|if\\(n?def\\)?\\|else\\|endif\\)")
        0)
       ;; If we're not inside a "true" block (i.e. "{}"), then indent=0
       ;; I think this is fair, since no (indentable) code in promela
       ;; exists outside of a proctype or similar "{ .. }" structure.
       ((zerop paren-depth)
        0)
       ;; Indent relative to non curly-brace "paren"
       ;; [ NOTE: I'm saving this, but don't use it any more.
       ;;         Now, we let parens be indented like curly braces
       ;;((and (>= paren-depth 1) (not (char-equal ?\{ paren-char)))
       ;; (goto-char paren-point)
       ;; (1+ (current-column)))
       ;; 
       ;; Last option: indent relative to contaning block(s)
       (t
        (goto-char orig-point)
        (promela-calc-indent-within-block paren-point))))))

(defun promela-calc-indent-within-block (&optional limit)
  "Return the appropriate indentation for this line, assume within block.
with optional arg, limit search back to `limit'"
  (save-excursion
    (let* ((stop 	 (or limit 1))
           (block-point  (promela-find-start-of-containing-block stop))
           (block-type   (promela-block-type-after block-point))
           (indent-point (point))
           (indent-type  (promela-block-type-after indent-point)))
      (if (not block-type) 0
        ;;(message "paren: %d (%d); block: %s (%d); indent: %s (%d); stop: %d"
        ;;         paren-depth paren-point block-type block-point
        ;;         indent-type indent-point stop)
        (goto-char block-point)
        (cond
         ;; Indent (options) inside "if" or "do"
         ((memq block-type '(selection iteration))
          (if (re-search-forward "\\(do\\|if\\)[ \t]*::" indent-point t)
              (- (current-column) 2)
            (+ (current-column) promela-selection-indent)))
         ;; indent (generic code) inside "::" option
         ((eq 'option block-type)
          (if (and (not indent-type)
                   (re-search-forward "::.*->[ \t]*\\sw"
                                      (save-excursion (end-of-line) (point))
                                      t))
              (1- (current-column))
            (+ (current-column) promela-selection-option-indent))
          )
         ;; indent code inside "{"
         ((eq 'block block-type)
          (cond
           ;; if we are indenting the end of a block,
           ;; use indentation of start-of-block
           ((equal 'block-end indent-type)
            (current-indentation))
           ;; if the start of the code inside the block is not at eol
           ;; then indent to the same column as the block start +some
           ;; [ but ignore comments after "{" ]
           ((and (not (promela-effective-eolp (1+ (point))))
                 (not (looking-at "{[ \t]*/\\*")))
            (forward-char)		; skip block-start
            (skip-chars-forward "{ \t") ; skip whitespace, if any
            (current-column))
           ;; anything else we indent +promela-block-indent from
           ;; the indentation of the start of block (where we are now)
           (t
            (+ (current-indentation)
               promela-block-indent))))
         ;; dunno what kind of block this is - sound an error
         (t
          (error "promela-calc-indent-within-block: unknown block type: %s" block-type)
          (current-indentation)))))))

(defun promela-calc-indent-within-comment ()
  "Return the indentation amount for line, assuming that the
current line is to be regarded as part of a block comment."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    (let ((indenting-end-of-comment (looking-at "\\*/"))
          (indenting-blank-line (eolp)))
      ;; if line is NOT blank and next char is NOT a "*'
      (if (not (or indenting-blank-line (= (following-char) ?\*)))
          ;; leave indent alone
          (current-column)
        ;; otherwise look back for _PREVIOUS_ possible nested comment start
        (let ((comment-start (save-excursion 
                               (re-search-backward comment-start-skip))))
          ;; and see if there is an appropriate middle-comment "*"
          (if (re-search-backward "^[ \t]+\\*" comment-start t)
              (current-indentation)
            ;; guess not, so indent relative to comment start
            (goto-char comment-start)
            (if indenting-end-of-comment
                (current-column)
              (1+ (current-column)))))))))


;; -------------------------------------------------------------------------
;; Misc other support functions

(defun promela-parse-partial-sexp (&optional start limit)
  "Return the partial parse state of current defun or from optional start
to end limit"
  (save-excursion
    (let ((end (or limit (point))))
      (if start
          (goto-char start)
        (promela-beginning-of-defun))
      (parse-partial-sexp (point) end))))

;;(defun promela-at-end-of-block-p ()
;;  "Return t if cursor is at the end of a promela block"
;;  (save-excursion
;;    (let ((eol (progn (end-of-line) (point))))
;;      (beginning-of-line)
;;      (skip-chars-forward " \t")
;;      ;;(re-search-forward "\\(}\\|\\b\\(od\\|fi\\)\\b\\)" eol t))))
;;      (looking-at "[ \t]*\\(od\\|fi\\)\\b"))))

(defun promela-inside-comment-p ()
  "Check if the point is inside a comment block."
  (save-excursion
    (let ((origpoint (point))
          state)
      (goto-char 1)
      (while (> origpoint (point))
	(setq state (parse-partial-sexp (point) origpoint 0)))
      (nth 4 state))))

(defun promela-inside-comment-or-string-p ()
  "Check if the point is inside a comment or a string."
  (save-excursion
    (let ((origpoint (point))
          state)
      (goto-char 1)
      (while (> origpoint (point))
	(setq state (parse-partial-sexp (point) origpoint 0)))
      (or (nth 3 state) (nth 4 state)))))


(defun promela-effective-eolp (&optional point)
  "Check if we are at the effective end-of-line, ignoring whitespace"
  (save-excursion
    (if point (goto-char point))
    (skip-chars-forward " \t")
    (eolp)))

(defun promela-check-expansion ()
  "If abbrev was made within a comment or a string, de-abbrev!"
  (if promela-inside-comment-or-string-p
	(unexpand-abbrev)))

(defun promela-block-type-after (&optional point)
  "Return the type of block after current point or parameter as a symbol.
Return one of 'iteration `do', 'selection `if', 'option `::',
'block `{' or `}' or nil if none of the above match."
  (save-excursion
    (goto-char (or point (point)))
    (skip-chars-forward " \t")
    (cond
     ((looking-at "do\\b") 'iteration)
     ;;((looking-at "od\\b") 'iteration-end)
     ((looking-at "if\\b") 'selection)
     ;;((looking-at "fi\\b") 'selection-end)
     ((looking-at "::") 'option)
     ((looking-at "[{(]") 'block)
     ((looking-at "[})]") 'block-end)
     (t nil))))

(defun promela-find-start-of-containing-comment (&optional limit)
  "Return the start point of the containing comment block.
Stop at `limit' or beginning of buffer."
  (let ((stop (or limit 1)))
    (save-excursion
      (while (and (>= (point) stop)
                  (nth 4 (promela-parse-partial-sexp)))
        (re-search-backward comment-start-skip stop t))
      (point))))

(defun promela-find-start-of-containing-block (&optional limit)
  "Return the start point of the containing `do', `if', `::' or
`{' block or containing comment.
Stop at `limit' or beginning of buffer."
  (save-excursion
    (skip-chars-forward " \t")
    (let* ((type  (promela-block-type-after))
           (stop  (or limit
                      (save-excursion (promela-beginning-of-defun) (point))))
           (state (promela-parse-partial-sexp stop))
           (level (if (looking-at "\\(od\\|fi\\)\\b")
                      2
                    (if (zerop (nth 0 state)) 0 1))))
      ;;(message "find-start-of-containing-block: type: %s; level %d; stop %d"
      ;;         type level stop)
      (while (and (> (point) stop) (not (zerop level)))
	(re-search-backward
             "\\({\\|}\\|::\\|\\b\\(do\\|od\\|if\\|fi\\)\\b\\)"
             stop 'move)
        ;;(message "looking from %d back-to %d" (point) stop)
	(setq state (promela-parse-partial-sexp stop))
	(setq level (+ level
                       (cond ((or (nth 3 state) (nth 4 state))    	 0)
                             ((and (= 1 level) (looking-at "::")
                                   (not (equal type 'option)))	  	-1)
                             ((looking-at "\\({\\|\\(do\\|if\\)\\b\\)") -1)
                             ((looking-at "\\(}\\|\\(od\\|fi\\)\\b\\)") +1)
                             (t 0)))))
      (point))))

(defun promela-find-start-of-containing-block-or-comment (&optional limit)
  "Return the start point of the containing comment or
the start of the containing `do', `if', `::' or `{' block.
Stop at limit or beginning of buffer."
  (if (promela-inside-comment-p)
      (promela-find-start-of-containing-comment limit)
    (promela-find-start-of-containing-block limit)))

;; -------------------------------------------------------------------------
;; Debugging/testing

;; (defun promela-mode-toggle-debug ()
;;   (interactive)
;;   (make-local-variable 'debug-on-error)
;;   (setq debug-on-error (not debug-on-error)))

;;(defun promela-mode-revert-buffer ()
;;  (interactive)
;;  (revert-buffer t t))

;; -------------------------------------------------------------------------
;;###autoload

(provide 'promela-mode)


;;----------------------------------------------------------------------
;; Change History:
;; 2014/05/22 rudi
;;  - turn on font lock (tiny change)
;;
;; 2014/03/20 rudi
;;  - make the mode work on recent Emacs (tested on Emacs 24.3)
;;    - removed references to font-lock-default-alist in emacs >=24
;;    - renamed last-command-char (obsolete since Emacs 19.34) to
;;      last-command-event
;;  - use `define-derived-mode' (do not derive from `prog-mode' yet
;;    since that is still too new)
;;  - use value of `promela-comment-col'
;;  - rely on newcomment to do comment indentation
;;
;;     migrated to git versioning...
;; Pre-git-History:
;;
;; Revision 1.11  2001/07/09 18:36:45  engstrom
;;  - added comments on use of font-lock-maximum-decoration
;;  - moved basic preprocess directive fontification to "level 2"
;;
;; Revision 1.10  2001/05/22 16:29:59  engstrom
;;  - fixed error introduced in fontification levels stuff (xemacs only)
;;
;; Revision 1.9  2001/05/22 16:21:29  engstrom
;;  - commented out the compilation / syntax check stuff for now
;;
;; Revision 1.8  2001/05/22 16:18:49  engstrom
;;  - Munched history in preparation for first non-Honeywell release
;;  - Added "levels" of fontification to be controlled by the std. variable:
;;      'font-lock-maximum-decoration'
;;
;; Revision 1.7  2001/04/20 01:41:46  engstrom
;; Revision 1.6  2001/04/06 23:57:18  engstrom
;; Revision 1.5  2001/04/04 20:04:15  engstrom
;; Revision 1.4  2001/03/15 02:22:18  engstrom
;; Revision 1.3  2001/03/09 19:39:51  engstrom
;; Revision 1.2  2001/03/01 18:07:47  engstrom
;; Revision 1.1  2001/02/01 xx:xx:xx  engstrom
;;     migrated to CVS versioning...
;; Pre-CVS-History:
;;   99-10-04 V0.4 EDE        Fixed bug in end-of-block indentation
;;                            Simplified indentation code significantly
;;   99-09-2x V0.3 EDE        Hacked on indentation more while at FM'99
;;   99-09-16 V0.2 EDE        Hacked, hacked, hacked on indentation
;;   99-04-01 V0.1 EDE        Introduced (less-than) half-baked indentation
;;   98-11-05 V0.0 EDE        Created - much code stolen from rexx-mode.el
;;                            Mostly just a fontification mode -
;;                            (indentation is HARD ;-)
;;
;; EOF promela-mode.el
