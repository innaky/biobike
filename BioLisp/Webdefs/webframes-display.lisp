;;; -*- Package: frames; mode: lisp; base: 10; Syntax: Common-Lisp; -*-

(in-package :frames)

;;; +=========================================================================+
;;; | Copyright (c) 2002, 2003, 2004 JP Massar, Jeff Shrager, Mike Travers    |
;;; |                                                                         |
;;; | Permission is hereby granted, free of charge, to any person obtaining   |
;;; | a copy of this software and associated documentation files (the         |
;;; | "Software"), to deal in the Software without restriction, including     |
;;; | without limitation the rights to use, copy, modify, merge, publish,     |
;;; | distribute, sublicense, and/or sell copies of the Software, and to      |
;;; | permit persons to whom the Software is furnished to do so, subject to   |
;;; | the following conditions:                                               |
;;; |                                                                         |
;;; | The above copyright notice and this permission notice shall be included |
;;; | in all copies or substantial portions of the Software.                  |
;;; |                                                                         |
;;; | THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         |
;;; | EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      |
;;; | MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  |
;;; | IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    |
;;; | CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    |
;;; | TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       |
;;; | SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  |
;;; +=========================================================================+


;;; Michael Travers 2003/4
;;; Massive hacking by JP Massar 11/04  

(defvar *current-object*)


;;; STATE VARIABLES FOR THE WEBLISTENER OBJECT BROWSER (WOB)

;;; Allow user to display longer or shorter lists when they are the
;;; values of slots, and eventually more or less children/parts.

(defvar *print-limit-normal* 30)
(defvar *print-limit-minimal* 6)
(defvar *print-limit-maximal* -1)

;;; If the user clicks MORE or LESS, the *print-limit* gets multiplied
;;; or divided, respectively, by this factor (subject to the minimum).

(defvar *print-limit-expansion-factor* 5)

;;; We set an absolute limit on how many characters of a string we are
;;; willing to show.

(defvar *print-limit-stringsize-upper-bound* 750)

(defmacro ddefvar (symbol default-value)
  `(progn 
     (defvar ,symbol)
     (setf (get ',symbol :default-value) ,default-value)
     ))

;;; State variables that get passed on through via every URL generated
;;; by this object browser.



(ddefvar *print-limit* *print-limit-normal*) 
(ddefvar *hide-parents* t)
(ddefvar *hide-children* t)
(ddefvar *hide-superparts* t)
(ddefvar *hide-parts* t)
(ddefvar *print-lispy* nil)
(ddefvar *elements-per-row* 5)

(defun maybe-bigger-print-limit ()
  (if (= *print-limit* *print-limit-maximal*)
      *print-limit*
    (* *print-limit* *print-limit-expansion-factor*)
    ))

(defun maybe-smaller-print-limit ()
  (if (= *print-limit* *print-limit-minimal*)
      *print-limit*
    (/ *print-limit* *print-limit-expansion-factor*)
    ))

;;; If we have a state variable *foo*, and :*foo* is a property
;;; on the property list of the current user's package symbol, then
;;; use that value as the default, otherwise use the standard default,
;;; which is stored on the property list of *foo* under :default-value.

(defun default-wob-state-variable-value (variable)
  (let ((kv (keywordize variable)))
    (or
     (and (forward-funcall 'wb::user-session-id)
          ;; Make sure a default for this variable has been explicitly defined
          (member kv (symbol-plist (forward-funcall 'wb::user-session-id)))
          ;; Return it
          (get (forward-funcall 'wb::user-session-id) kv))
     (get variable :default-value)
     )))

(defun set-wob-state-variable-value (variable value)
  (setf (get (forward-funcall 'wb::user-session-id) 
             (keywordize variable)) value))

        
(defun state-variable-to-integer (symbol)
  (let ((value (symbol-value symbol)))
    (setf (symbol-value symbol)
          (if (null value)
              (default-wob-state-variable-value symbol)
            (or (ignore-errors (parse-integer value))
                (default-wob-state-variable-value symbol)
                )))))

(defun state-variable-to-boolean (symbol)
  (let ((value (symbol-value symbol)))
    (setf (symbol-value symbol)
          (if (null value)
              (default-wob-state-variable-value symbol)
            (cond
             ((string-equal value "NIL") nil)
             (t t)
             )))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; IMPLEMENTATION OF WEBLISTENER OBJECT BROWSER INSTANCE TABLE

(defvar *wob-table* (make-hash-table :test 'equal))

(defun object-from-unique-id (unique-id) 
  (first (gethash unique-id *wob-table*)))
(defun unique-id-from-object (object) 
  (gethash object *wob-table*))

(defun purge-wob-table (seconds-ago)
  (let* ((now (get-universal-time))
         (purge-cutoff (- now seconds-ago))
         (ht *wob-table*)
         ;; Find all the expired timestamps in the wob hash table
         ;; and get their associated objects and their keys which are 
         ;; the objects unique-ids.
         (expired-ids-and-objects
          (lmaphashnn
           (lambda (key value)
             (when (and (listp value) (second value) (integerp (second value)))
               (destructuring-bind (object timestamp) 
                   value
                 (when (< timestamp purge-cutoff)
                   (list key object) 
                   ))))
           ht
           )))
    ;; For each expired entry
    ;; Remove the object -> unique-id mapping 
    ;; Remove the unique-id -> (object timestamp) mapping
    (loop for (unique-id object) in expired-ids-and-objects do
          (remhash unique-id ht)
          (remhash object ht)
          )))
         

(let ((unique-counter 0))
  (defun enter-object-into-or-update-wob (object)
    ;; See if OBJECT is already in our hash table.
    (let ((unique-id (gethash object *wob-table*)))
      ;; If not, create a unique-id for it
      (unless unique-id
        ;; This number will be unique with respect to this hash table
        ;; for this process.
        (setq unique-id (incf unique-counter))
        (setf (gethash object *wob-table*) unique-id)
        )
      ;; Update timestamp
      (setf (gethash unique-id *wob-table*) (list object (get-universal-time)))
      unique-id
      )))

(defun remove-object-from-wob (object)
  (let ((unique-id (gethash object *wob-table*)))
    (if unique-id
        (progn
          (remhash unique-id *wob-table*)
          (remhash object *wob-table*)
          t)
      nil
      )))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;; EMIT-VALUE METHODS AND AUXILIARY FUNCTIONS


(defun print-limit-or-nil ()
  (if (eql *print-limit* *print-limit-maximal*) nil *print-limit*))

(defun emit-lispy-or-block (thing)
  (if *print-lispy* 
      (html (:prin1-safe thing))
    (html (:princ-safe thing))
    ))

(defun emit-literal-string (s) (html (:princ-safe s)))

(defun emit-more-link (n-elements-not-shown)
  (html
   ((:a :href (wob-url *current-object*))
    (:small
     (:princ-safe 
      (formatn "<<~D more>>" n-elements-not-shown)
      )))
   :newline
   ))

(defun emit-elements-upto (seq last-index)
  (block exit
    (flet ((doit (elem index) 
             (emit-value elem)
             (if (= index last-index) 
                 (return-from exit)
               (emit-literal-string " "))))
      (if (consp seq) 
          (loop for elem in seq for j from 0 to last-index do (doit elem j))
        (loop for elem across seq for j from 0 to last-index do (doit elem j))
        ))))

               
(defun emit-initial-elements (sequence last-index n-elements-not-shown)
  (emit-elements-upto sequence last-index)
  (emit-literal-string " ... ")
  (let ((*print-limit* (maybe-bigger-print-limit)))
    (emit-more-link n-elements-not-shown)
    ))

(defun emit-circular-list (list)
  (emit-literal-string "<<Circular List>> (")
  (emit-value (first list))
  (emit-literal-string " ...)"))


;;; EMIT-VALUE methods

;;; Frames.  Make a link.

(defmethod emit-value 
           ((object #-:jpmtf %frame #+:jpmtf sw::frame)
            &optional (print-limit (print-limit-or-nil)))
  (declare (ignore print-limit))
  (html
   ((:a :href (wob-url object))
    "#$"
    (:princ-safe (slotv object #$fName)))
   :newline
   ))


;;; NIL
;;; Special case so doesn't get printed out as ()

(defparameter *block-nil-html* nil)

(defmethod emit-value 
           ((object null) &optional (print-limit (print-limit-or-nil))) 
  (declare (ignore print-limit))
  (cond
   (*print-lispy* (emit-literal-string "NIL"))
   (*block-nil-html* (html (:princ *block-nil-html*)))
   (t (emit-literal-string "-"))
   ))


;;; Strings`.  Treat the print-limit as if it were five times as big
;;; (so we will show five times as many chars as list elements, say)

(defmethod emit-value
           ((object string) &optional (print-limit (print-limit-or-nil))) 
  (let* ((len (length object))
         (limit
          (if (null print-limit)
              *print-limit-stringsize-upper-bound*
            (min (* print-limit *print-limit-expansion-factor*)
                 *print-limit-stringsize-upper-bound*
                 ))))
    (if (<= len limit)
        ;; Show the whole string
        (emit-lispy-or-block-string object)
      ;; Figure out how much of the string to show, and whatnot
      (let* ((trailer "... ")
             (more-template "((~D more))")
             (more-chars-string-size (length (formatn more-template len)))
             (trim-size (+ (length trailer) more-chars-string-size))
             (n-chars-from-string-emitted (- limit trim-size))
             (substring 
              (one-string
               (subseq object 0 n-chars-from-string-emitted)
               trailer
               ))
             (n-more-chars (- len n-chars-from-string-emitted))
             (more-chars-text (formatn more-template n-more-chars))
             )
        (if (>= len *print-limit-stringsize-upper-bound*)
             ;; Show the maximum amount we allow of the string,
            ;; without any link to show more.
            (emit-lispy-or-block-string (one-string substring more-chars-text))
          (let ((*print-limit* (maybe-bigger-print-limit)))
            ;; Show the initial substring with a trailing '...'
            ;; and a link to increase the amount shown which says
            ;; how many more characters the string contains.
            (emit-lispy-or-block-string substring)
            (emit-more-link n-more-chars)
            ))))))

(defun emit-lispy-or-block-string (s)
  (if *print-lispy*
      (progn
        (html (:princ "\""))
        (loop for ch across s do
              (case ch
                (#\Space (html (:princ "&nbsp;")))
                (#\\ (html (:princ "\\\\")))
                (#\" (html (:princ "\\")))
                ;; Maybe need other special cases here?
                (otherwise (html (:princ-safe (string ch))))
                ))
        (html (:princ "\"")))
    (loop for ch across s do
          (case ch
            (#\Space (html (:princ "&nbsp;")))
            (otherwise (html (:princ-safe (string ch))))
            ))))
    

;;; A random object.  This seems to work for Allegro and Lispworks.
;;; I'm not sure it's completely portable.

(defmethod emit-value 
           ((object t) &optional (print-limit (print-limit-or-nil)))
  (declare (ignore print-limit))
  (let ((class-type (type-of (class-of object))))
    (cond 
     ;; A random Common Lisp type
     ((eq class-type 'built-in-class)
      (emit-lispy-or-block object))
     ;; A Common Lisp type that might or might not be 'built-in'
     ;; and that might or not not be 'standard-class'
     ((or (streamp object)
          (readtablep object)
          (hash-table-p object)
          (packagep object)
          (pathnamep object)
          )
      (emit-lispy-or-block object))
     ;; At this point, we think it must be a user-defined instance
     ;; if its class is STANDARD-CLASS.  Note that if there were
     ;; a class which was not STANDARD-CLASS, and we were given an 
     ;; instance of that class to emit, this would fail to show it's
     ;; slot names and slot values (which is just as well, because
     ;; if it's not STANDARD-CLASS, we really aren't sure of how
     ;; to get at its slot names and slot values (?))
     ((eq class-type 'standard-class)
      (emit-user-class-instance object))
     (t 
      (emit-lispy-or-block object)
      ))))


;;; Vectors.  Subject to *PRINT-LIMIT*.

(defmethod emit-value
           ((object vector) &optional (print-limit (print-limit-or-nil))) 
  (let* ((len (length object))
         (n-elements-to-emit
          (if (null print-limit) len (min print-limit len)))
         (all? (= len n-elements-to-emit))
         (n-elements-not-shown (- len n-elements-to-emit))
         (last-index (1- n-elements-to-emit))
         )
    (html 
     (:princ-safe "#(")
     (if all?
         ;; Emit all the elements with a space between each one.
         (emit-elements-upto object last-index)
       ;; Emit N-ELEMENTS-TO-EMIT elements, followed by ...
       ;; followed by a hyperlink which will cause more elements to
       ;; be shown and whose next says how many more elements there are.
       (emit-initial-elements object last-index n-elements-not-shown)
       )
     (:princ-safe ")")
     :newline
     )))

  
;;; Lists.  Subject to *PRINT-LIMIT*.

(defmethod emit-value 

           ((object list) 
            &optional (print-limit (print-limit-or-nil))
            &aux n-elements-to-emit n-elements-not-shown all? last-index
            )

  (multiple-value-bind (len type)
      (length-circular-or-dotted? object)

    ;; LEN will only be NIL if the list is circular.
    ;; Otherwise LEN will be the number of elements for a proper list
    ;; and the number of elements for a dotted list counting the cdr
    ;; of the last cons cell as an element.

    (unless (null len)
      (setq n-elements-to-emit
            (if (null print-limit) len (min print-limit len)))
      (setq all? (= len n-elements-to-emit))
      (setq n-elements-not-shown (- len n-elements-to-emit))
      (setq last-index (1- n-elements-to-emit))
      )

    (if *print-lispy*

        ;; Standard Lisp format with nested parentheses

        (ecase type
          (:proper
           (html 
            (:princ-safe "(")
            (if all?
                ;; Emit all the elements with a space between each one.
                (emit-elements-upto object last-index)
              ;; Emit N-ELEMENTS-TO-EMIT elements, followed by ...
              ;; followed by a hyperlink which will cause more elements to
              ;; be shown and whose next says how many more elements there are.
              (emit-initial-elements object last-index n-elements-not-shown)
              )
            (:princ-safe ")")
            :newline
            ))
          (:dotted
           (html 
            (:princ-safe "(")
            (if all?
                ;; Emit with last element in dotted-pair notation
                (progn
                  (emit-elements-upto object (1- last-index))
                  (emit-literal-string " . ")
                  (emit-value (cdr (last object))))
              ;; If we're not emitting all the elements we don't have
              ;; to worry about the dotted pair at the end.
              (emit-initial-elements object last-index n-elements-not-shown)
              )
              (:princ-safe ")")
              :newline
              ))
          (:circular (emit-circular-list object))
          )
                      
      ;; Block (html tablular) style

      (ecase type
        (:circular (emit-circular-list object))
        ;; We could do better than this, maybe the top row saying
        ;; the thing is a dotted list?
        (:dotted
         (emit-literal-string "<<Dotted list -- Use 'Format: Lisp' to view>>"))
        (:proper
         (html 
          ((:table :border 1 :cellpadding 3 :cellspacing 0 
            :rules "all" :frame "void")
           :newline
           (loop with per-row = *elements-per-row*
                 with count = 0
                 for rest on object by (lambda (x) (nthcdr per-row x))
                 until (>= count n-elements-to-emit)
                 do
                 (html
                  (:tr
                   (loop for elems on rest
                         for i fixnum from 0 below per-row
                         until (>= count n-elements-to-emit) do
                         (incf count)
                         (when elems 
                           (html (:td (emit-value (first elems))) :newline)
                           )))
                  :newline))
           (unless all?
             (html 
              (:tr 
               ((:td :colspan *elements-per-row*)
                (let ((*print-limit* (maybe-bigger-print-limit)))
                  (emit-more-link n-elements-not-shown)
                  )))
              :newline
              ))))))
                             
      )))


(defun emit-user-class-instance (object)
  (forward-funcall 'enter-object-into-or-update-wob object)
  (let ((url (wob-url object)) (text (formatn "~A" object)))
    (html 
     ((:a :href url) ((:font :color :brown) (:princ-safe text)))
     :newline
     )))
    

;;; slot on slots that specify HTML
(def-inherited-slot #$HTMLGenerator)

;;; slot whose value is an URL string 
(defslot #$URLvalue)


;;; Turn these HTMLGenerator function objects stored in slots
;;; into symbols representing functions so we can write frames
;;; out to disk w/o dealing with function objects.  JP.  8/31/04

(defun html-for-urlvalue-slot (url-string)
  ;; Actually, the URL-STRING probably needs to be escaped
  (html ((:a :href url-string) (:princ-safe url-string))))

(defun html-for-imagevalue-slot (url-string)
  (when url-string
    (html ((:img :src url-string :border 0)))))

#-:jpmtf
(setf (slotv #$URLvalue #$HTMLGenerator) 'html-for-urlvalue-slot)

      ;; (lambda (val) (html ((:a :href val) (:princ-safe val)))))


;;; the value of this type of slot is a URL designating an image
(defslot #$imageValue)

#-:jpmtf
(setf (slotv #$imageValue #$HTMLGenerator) 'html-for-imagevalue-slot)


;;; If this gets to be a real feature, this may want to be a fast slot 
;;; (ie a slot of the frame defstruct) since it will get referenced a lot.
(def-inherited-slot #$fillMethod)


(defun emit-hierarchy 
       (frame slot &optional (print-limit (print-limit-or-nil)))
  ;; Hack to make it not print itself when no children.  JP.
  (when (slotv frame slot)
    (recursive-descent 
     frame 
     ;; child generator
     (lambda (f) 
       (when (framep f)
         (let ((raw (slotv f slot)))
           (if (and print-limit (> (length raw) print-limit))
               (nconc (subseq raw 0 print-limit)
                      `((:more ,(- (length raw) print-limit))))
             raw))))
     ;; procedure
     (lambda (frame)
       (html :br)
       (dotimes (n *recursive-descent-level*)
         (emit-literal-string ".."))
       (cond
        ;; No point providing hyperlink to the page we're already viewing
        ((eq frame *current-object*)
         (html (:b "#$" (:princ-safe (slotv frame #$fName)))))
        ;; We've hit the :MORE designator.  Can't happen if *print-limit*
        ;; is equal to *print-limit-maximal*
        ((listp frame) 
         (let ((*print-limit* (maybe-bigger-print-limit)))
           (emit-more-link (cadr frame))))
        (t (emit-value frame))
        )))))




;;; This inverts a DAG subgraph and turns it into a tree for display. 
;;; It's relatively complex because it has to recurse down the original graph
;;; and build a new one.

(defun dag->tree (frame &optional (slot #$isA))
  (let ((forest nil))			;a list of trees
    (labels ((build-tree (fr)
	       (vif (x (forest-find fr forest))
		    x
		    (vif (x (slotv fr slot))
			 (let ((result nil))
			   (dolist (parent x)
			     (let ((parent-entry (build-tree parent)))
			       (setf result (list fr))
			       (push result (cdr parent-entry))))
			   result)
			 ;; No parent and not in trees yet
			 (let ((result (list fr)))
			   (push result forest)
			   result)))))
      (build-tree frame)
      forest)))

(defun tree-find2 (thing tree)
  (vif (x (eq thing (car tree)))
       tree
       (dolist (sub (cdr tree))
	 (vwhen (x (tree-find2 thing sub))
		(return x)))))

(defun forest-find (thing forest)
  (dolist (tree forest)
    (vwhen (x (tree-find2 thing tree))
	   (return x))))

;;; +++ trim using *print-limit*
(defun emit-parents (start-frame &optional (slot #$isA))
  (let ((forest (dag->tree start-frame slot)))
    ;; A hack to stop it from printing out itself as a parent.  JP.
    (unless (and (= (length forest) 1) 
                 (listp (first forest))
                 (= (length (first forest)) 1)
                 (eq (caar forest) start-frame))
      (dolist (tree forest)
        (recursive-descent
         tree
         #'cdr
         (lambda (tree-node)
           (html :br)
           (dotimes (n *recursive-descent-level*)
             (emit-literal-string ".."))
           (let ((frame (car tree-node)))
             (if (eq frame start-frame)
                 (html (:b "#$" (:princ-safe (slotv frame #$fName))))
               (emit-value frame)
               ))))))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    

(defmethod wob-url ((object t))
  (let ((id (gethash object *wob-table*)))
    (unless id (error "Internal error.  No id for instance object ~A" object))
    (formatn
     (one-string
      "/browse-class-instance.html"
      (wob-state-variable-values-url-argstring)
      "&uniqueid=~A")
      id
      )))

(defmethod wob-url ((object #-:jpmtf %frame #+:jpmtf sw::frame))
  (formatn
   (one-string
    "/frame"
    (wob-state-variable-values-url-argstring)
    "&name=~A")
   (url-safe-string (slotv object #$fName))
   ))


(defmethod wob-html ((frame #-:jpmtf %frame #+:jpmtf sw::frame))

  ;; Generate HTML output for a frame

  (labels ((emit-section-title (title)
             (html :p (:b (:i (:princ-safe title))) "   " :newline))
           (emit-section-show-hide-control (hide-varname)
             (let ((opposite-value (null (symbol-value hide-varname))))
               (html
                ((:a :href 
                  (progv (list hide-varname) (list opposite-value)
                    (wob-url frame)))
                 (if opposite-value "[Hide]" "[Show]"))
                :newline
                )))
           (emit-section-header (title hide-variable)
             (emit-section-title title)
             (emit-section-show-hide-control hide-variable)))

    (let ((*current-object* frame))

      ;; Generate a table, one row for each slot/value pair in the frame.
      ;; The first column show the slot name, the second shows the value
      ;; in a format controlled by the state variables.

      (html 
       ((:table :border 1 :cellpadding 3 :cellspacing 0)
        :newline
	(:tr
	 (:th "Slot Name")
	 (:th "Slot Value"))
        :newline
        ;; general frame description 
        ;; (should leave out ones done as hierarchy)
        (let ((slots 
               #-:jpmtf
               (copy-list (%frame-slots frame))
               #+:jpmtf
               ;; get rid of :scalar-hack hack for display
               (let ((list nil))
                 (frames::for-each-frame-slot (s v) frame
                     (push (list s (frames::slotv frame s)) list))
                 (reverse list))
               ))
          ;; display slots and values in alphabetical order by slot name.
          (setq slots (sort slots 'string-lessp
                            :key (lambda (x) (slotv (first x) #$Fname))))
          (loop for (slot-frame . slot-value) in slots do
                (when (member #$AlwaysComputedSlot (slotv slot-frame #$isA))
                  (setq slot-value (slotv frame slot-frame)))
                (html
                 (:tr
                  (:td
                   ((:a :href 
                     (forward-funcall 
                      'wb::make-weblistener-evalstring-url
                      :evalstring
                      (url-safe-string 
                       (prin1-to-string `(slotv ,frame ,slot-frame)))
                      :pkg (forward-funcall 'wb::user-session-id)
                      ))
                    :newline
                    ((:font :color :green) (:princ-safe "#^")))
                   ((:a :href (wob-url slot-frame))
                    (:princ-safe (slotv slot-frame #$Fname)))
                   :newline
                    )
                  (:td
		   (emit-slot-value slot-frame slot-value)
		   ))
                 :newline
                 )))))

      (when (slotv frame #$isA)
        (emit-section-header "Parents" '*hide-parents*)
        (emit-parents frame #$isA))
      (when (slotv frame #$subclasses)
        (emit-section-header "Children" '*hide-children*)
        (emit-hierarchy frame #$subclasses))
      (when (slotv frame #$partOf)
        (emit-section-header "SuperParts" '*hide-superparts*)
        (emit-parents frame #$partOf))
      (when (slotv frame #$parts)
        (emit-section-header "Parts" '*hide-parts*)
        (emit-hierarchy frame #$parts))

      )))

(defun emit-slot-value (slot-frame slot-value)
  (vif (html-generator
	(and (not *print-lispy*) 
	     (slotv slot-frame #$HTMLGenerator)))
       (funcall html-generator slot-value)
       (emit-value slot-value)
       ))

(defmethod wob-html ((instance t))

  ;; Generate HTML output for what is hopefully a CLOS object
  ;; (all other kinds of objects should be caught before this 
  ;; generic function is called)

  (let ((names-and-values (utils:slot-names-and-slot-values instance))
        (title "Slot Name | Slot Value")
        (*current-object* instance)
        )

    (html :p (:b (:i (:princ-safe title))) "   " :newline)

    ;; Generate a table, one row for each slot name/slot value in the object.
    ;; The first column show the slot name, the second shows the value
    ;; in a format controlled by the state variables.

    (html 
     ((:table :border 1 :cellpadding 3 :cellspacing 0)
      (setq names-and-values
            (sort names-and-values 'string-lessp
                  :key (lambda (x) (string (first x)))
                  ))
      (loop for (slot-name slot-value) in names-and-values do
            (let* ((ns (string slot-name)) (lenns (length ns)))
              (html
               :newline
               (:tr
                ;; Pad out one and two letter slot names so
                ;; the table output looks reasonable
                (cond
                 ((= 1 lenns)
                  (html (:td "&nbsp; " (:princ-safe ns) "&nbsp; ")))
                 ((= 2 lenns)
                  (html (:td (:princ-safe ns) "&nbsp; ")))
                 (t (html (:td (:princ-safe ns))))
                 )
                :newline
                (:td (emit-value slot-value))
                :newline
                ))))))))



(defun emit-adjuster 
       (object visible-label deactivate? new-print-limit)
  (if deactivate?
      ;; No hyperlink
      (html (:princ visible-label) (:princ "    ") :newline)
    (html
     ;; A hyperlink for OBJECT that will change *PRINT-LIMIT*
     ;; and hence possibly change how the components of OBJECT
     ;; get displayed.
     ((:a :href 
       (let ((*print-limit* new-print-limit)) (wob-url object)))
      (:princ visible-label))
     (:princ "    ")
     :newline
     )))
	 
(defun emit-min-less-more-max-control (object)
  (emit-adjuster 
   object "Min"
   (eql *print-limit* *print-limit-minimal*) 
   *print-limit-minimal*)
  (emit-adjuster 
   object "Less" 
   (eql *print-limit-minimal* *print-limit*)
   (maybe-smaller-print-limit))
  (emit-adjuster 
   object "More" 
   (eq *print-limit* *print-limit-maximal*)
   (maybe-bigger-print-limit))
  (emit-adjuster
   object "Max"
   (eq *print-limit* *print-limit-maximal*)
   *print-limit-maximal*
   ))

(defun emit-block-format-or-lisp-format-control (object)
  (html
   ((:a :href 
     (let ((*print-lispy* (not *print-lispy*))) (wob-url object)))
    (:princ-safe (if *print-lispy* "Format: Block" "Format: Lisp")))
   :newline
   ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmacro with-wob-state-variable-values ((req) &body body)
  (let ((assoc (gensym "URL-ASSOC-LIST-")))
    `(let* ((,assoc (request-query ,req))
            (*print-limit* (url-parameter-value :printlimit ,assoc nil))
            (*print-lispy* (url-parameter-value :printlispy ,assoc nil))
            (*hide-parents* (url-parameter-value :hideparents ,assoc nil))
            (*hide-children* (url-parameter-value :hidechildren ,assoc nil))
            (*hide-superparts* (url-parameter-value :hidesuperparts ,assoc nil))
            (*hide-parts* (url-parameter-value :hideparts ,assoc nil))
            (*elements-per-row* 
             (url-parameter-value :elementsperrow ,assoc nil))
            )
       ;; (setq *assoc* ,assoc)
       (state-variable-to-integer '*print-limit*)
       (state-variable-to-boolean '*print-lispy*)
       (state-variable-to-boolean '*hide-parents*)
       (state-variable-to-boolean '*hide-children*)
       (state-variable-to-boolean '*hide-superparts*)
       (state-variable-to-boolean '*hide-parts*) 
       (state-variable-to-integer '*elements-per-row*)
       ,@body
       )))

(defmacro with-wob-state-variables-bound-to-defaults (&body body)
  `(let ((*print-limit* (get '*print-limit* :default-value))
         (*print-lispy* (get '*print-lispy* :default-value))
         (*hide-parents* (get '*hide-parents* :default-value))
         (*hide-children* (get '*hide-children* :default-value))
         (*hide-superparts* (get 'hide-superparts* :default-value))
         (*hide-parts* (get '*hide-parts* :default-value))
         (*elements-per-row* (get '*elements-per-row* :default-value))
         )
     ,@body
     ))

(defun wob-state-variable-values-url-argstring ()
  (formatn
   (one-string
    "?pkg=~A"
    "&printlimit=~D"
    "&printlispy=~A"
    "&hideparents=~A"
    "&hidechildren=~A"   
    "&hidesuperparts=~A"
    "&hideparts=~A"
    "&elementsperrow=~D"
    )
   (forward-funcall 'wb::user-session-id)
   *print-limit*
   *print-lispy*
   *hide-parents*
   *hide-children*
   *hide-superparts*
   *hide-parts*
   *elements-per-row*
   ))




(publish 
 :path "/browse-class-instance.html"
 :content-type cl-user::*html-publish-content-type*
 :function
 (lambda (req ent)
   (let* ((input (request-query req))
          (package-name (url-parameter-value :pkg input))
          (package-symbol (keywordize package-name))
          (unique-id (url-parameter-value :uniqueid input))
          )
       (wb::execute-with-standard-weblistener-environment
        req ent package-symbol
        (lambda () 
          (with-wob-state-variable-values (req)
            (html-for-browse-class-instance unique-id)))))))

(defun emit-class-link-deactivated ()
  (html 
   (:b
    "Ruh roh! "
    "Link deactivated because it has not been referenced "
    "for a long time.")
   :br
   "Go back to the previous page, do a RELOAD, and try the "
   "link again."
   ))

(defun emit-class-controls (unique-id instance)
  (emit-min-less-more-max-control instance)
  (emit-block-format-or-lisp-format-control instance)
  (html
   (:princ "    ")
   (when (forward-funcall 'wb::user-session-id)
     (html 
      ;; Send the object back as the output of
      ;; a faked user typein.
      ((:a :href 
        (forward-funcall 
         'wb::make-weblistener-evalstring-url
         :evalstring
         (url-safe-string 
          (formatn 
           "(frames::object-from-unique-id ~A)" unique-id))
         :pkg (forward-funcall 'wb::user-session-id)
         ))
       (:b (:princ-safe "Object->Listener")))))
   :br :br
   ))

(defun rejuvinate-object-in-browser-cache (instance unique-id)
  (setf (gethash unique-id *wob-table*) (list instance (get-universal-time))))


(defun html-for-browse-class-instance (unique-id)
  (let* ((unique-id (parse-integer unique-id))
         (unique-id-data (gethash unique-id *wob-table*))
         (instance (first unique-id-data)))
    (emit-html-for-browse-class-instance instance unique-id)
    ))

(defmethod emit-html-for-browse-class-instance ((instance t) unique-id)
  (let* ((class-name (class-name (class-of instance)))
         (title
          (if (null instance)
              "Ruh roh!"
            (format nil "An instance of Class '~A'" class-name)
            )))
    (wb::with-standard-weblistener-page-header (title)
      (if (null instance)
          (emit-class-link-deactivated)
        (progn
          ;; Rejuvinate the link.
          (rejuvinate-object-in-browser-cache instance unique-id)
          (emit-class-controls unique-id instance)
          ;; Output the slot names and slot values of the instance
          (wob-html instance)
          )))))

(defmethod emit-html-for-browse-class-instance 
           ((g utils::garray) unique-id)
  (let* ((rank (utils::garray-rank g))
         (title (format nil "A ~A of ~D dimensions" "Table" rank)))
    (wb::with-standard-weblistener-page-header (title)
      (rejuvinate-object-in-browser-cache g unique-id)
      (emit-class-controls unique-id g)
      (html 
       (:pre
        (:princ-safe 
         (with-output-to-string (s) 
           (let ((*standard-output* s))
             (utils::describe-garray g :details? nil :header? nil)
             )))
        :br 
        ))
      (case rank
        (1 (emit-html-for-1d-garray g))
        (2 (emit-html-for-2d-garray g))
        (3 
         (html (:b "Cannot display 3 or more dimensional tables yet!"))
         )))))

(defun value-or-if-not-there (g if-not-there? &rest indices)
  (handler-case 
      (apply 'gref g indices)
    (error () if-not-there?)
    ))

(defun emit-html-for-1d-garray (g)
  (let* ((max-display-size 1024)
         (axis (first (garray-axes g)))
         (all-keys 
          (utils::sorted-garray-indices axis (garray-component-indices g)))
         (size (length all-keys)))
    (when (> size max-display-size)
      (html 
       :br 
       (:princ-safe (formatn "(First ~D elements)" max-display-size))
       :br :br
       ))
    (html 
     ((:table :border 1 :cellpadding 3 :cellspacing 0)
      (loop for k in all-keys 
            for j from 1 to max-display-size 
            as v = (value-or-if-not-there g '- k)
            do 
            (html 
             :newline 
             (:tr 
              (:td (:princ-safe (utils::keystring k)))
              (:td (emit-value v))
              )))))))

(defun emit-html-for-2d-garray (g)
  (let* ((starting-row 1)
         (starting-col 1)
         (max-display-rows 256)
         (max-display-cols 16)
         (axes (garray-axes g))
         (first-axis (first axes))
         (second-axis (second axes)))
    (flet ((simple-2d-table (fa-keys sa-keys)
             (let ((n-fakeys (length fa-keys))
                   (n-sakeys (length sa-keys)))
               (when (or (> n-fakeys max-display-rows)
                         (> n-sakeys max-display-cols))
                 (html 
                  (when (> n-fakeys max-display-rows)
                    (html
                     (:princ-safe (formatn "(First ~D rows)" max-display-rows))
                     :br
                     ))
                  (when (> n-sakeys max-display-cols)
                    (html
                     (:princ-safe
                      (formatn "(First ~D columns)" max-display-cols))
                     :br
                     ))
                  :br
                  )))
             (html 
              ((:table :border 1 :cellpadding 3 :cellspacing 0)
               ;; header row
               (:tr 
                (:td "")
                (loop 
                 for i2 in sa-keys 
                 for c from starting-col to (+ starting-col max-display-cols -1)
                 do 
                 (html ((:td :align "center") 
                        (:princ-safe (utils::keystring i2))))
                 ))
               ;; data rows
               (loop 
                for i1 in fa-keys 
                for c1 from starting-row to (+ starting-row max-display-rows -1)
                do 
                (html
                 :newline 
                 (:tr 
                  (:td (:princ-safe (utils::keystring i1)))
                  (loop
                   for i2 in sa-keys 
                   for c2 from starting-col 
                   to (+ starting-col max-display-cols -1)
                   as v = (value-or-if-not-there g '- i1 i2)
                   do 
                   (html (:td (emit-value v)))
                   ))))))))
      (cond
       ((typep second-axis 'utils::num-axis)
        (let* ((all-first-axis-keys 
                (utils::sorted-garray-indices
                 first-axis (garray-component-indices g)))
               (all-second-axis-keys 
                (utils::sorted-garray-indices 
                 second-axis 
                 (garray-component-indices g (first all-first-axis-keys))
                 )))
          (simple-2d-table all-first-axis-keys all-second-axis-keys)
          ))
       (t 
        ;; figure out if the keys for each hash table along the second axis
        ;; are all subsets of the keys of the hash table with the most keys.  
        ;; If so, print the table in tabular form
        ;; using the keys of the hash table
        ;; with the most keys, otherwise give up.  
        (let* ((all-first-axis-keys 
                (utils::sorted-garray-indices
                 first-axis (garray-component-indices g)))
               (second-axis-keys 
                (utils::find-minimal-set-of-keys g all-first-axis-keys)
                ))
          (if second-axis-keys 
              (simple-2d-table all-first-axis-keys second-axis-keys)
            (html 
             (:b
              (:princ-safe "Cannot display when second axis has disparate keys")
              ))))))
      )))
           

(publish 
 :path wb::*weblistener-frames-url*
 :content-type cl-user::*html-publish-content-type*
 :function
 (lambda (req ent)
   (let* ((input (request-query req))
          (package-name (url-parameter-value :pkg input))
          (package-symbol (keywordize package-name))
          (name (url-parameter-value :name input))
          )
     (wb::execute-with-standard-weblistener-environment
      req ent package-symbol
      (lambda () 
        (when (find-package :wb)
          (forward-package-funcall :wb :log-user-event "Frame view: ~A~%" name))
        (with-wob-state-variable-values 
         (req)
         (html-for-browse-frame name)))))))


(defun html-for-browse-frame (name)
  (let* ((frame (frame-fnamed name))
         (title (formatn "Frame #$~A" name)))
    (wb::with-standard-weblistener-page-header (title)
      (if frame
          (progn
            (emit-min-less-more-max-control frame)
            (emit-block-format-or-lisp-format-control frame)
            (html (:princ "    "))
            (when (forward-funcall 'wb::user-session-id)
              (html 
               ;; Send the frame back as a faked user typein.
               ((:a :href 
                 (forward-funcall 
                  'wb::make-weblistener-evalstring-url
                  :evalstring
                  (formatn 
                   "%23%24~A" (url-safe-string (slotv frame #$fName)))
                  :pkg (forward-funcall 'wb::user-session-id)
                  ))
                (:princ-safe "Frame->Listener"))
               :newline))
            (html :br :br)
            (wob-html frame)
            )
        (html (:i "Frame not found.  (May have been uninterned)") :newline)
        )))
   ;; Any time we use the frame browser we purge the WOB table
   ;; of timed-out references so that they don't accumulate forever.
   (purge-wob-table (* 3600 3))
   )


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; FRAME FINDER FORM and FRAME FINDER RESULTS DISPLAY

(publish 
 :path wb::*weblistener-frame-find-url*
 :content-type cl-user::*html-publish-content-type*
 :function
 (lambda (req ent)
   (let* ((input (request-query req))
          (package-name (url-parameter-value :pkg input))
          (package-symbol (keywordize package-name))
          (substring (url-parameter-value :nstr input))
          (thorough (url-parameter-value :thorough input))
          )
     (wb::execute-with-standard-weblistener-environment
      req ent package-symbol
      (lambda () 
        (with-wob-state-variable-values (req)
          (html-for-frame-find substring thorough)))))))


(defun html-for-frame-find (substring thorough)

  (wb::with-standard-weblistener-page-header ("FIND-FRAMES")

    ;; Search interface.  This is all that will appear
    ;; when the URL is initially invoked.
    (when substring (setf substring (string-trim '(#\space) substring)))
    (html
     ((:form :action "frame-find" :method "get" :name "f")
      ((:input :type "text" :name "nstr" 
        :if* substring :value substring))
      ((:input :type "submit" :name "doit" :value "Find"))
      :br
      "Search definitions and synonyms"
      ((:input :type "checkbox" :name "thorough" 
        :if* thorough :checked "yes"))
      ((:input :type "HIDDEN" :name "PKG" 
        :value (string (forward-funcall 'wb::user-session-id))))
      )

     ;; Query results.

     (when (plusp (length substring))
       ;; Search through all frames for SUBSTRING
       (let* ((result 
               (if thorough
                   (forward-funcall 'googleplex-frames substring)
                 (forward-funcall 'google-frames substring)
                 ))
              (rlen (length result)))
         ;; Display up to 1000 results.
         (html 
          (:h3
           (:princ-safe 
            (formatn 
             "~A frame~P contain~A \"~A\"~A" 
             (if (zerop rlen) "No" rlen) 
             rlen 
             (if (= rlen 1) "s" "")
             substring
             (if (zerop rlen) "." ":")
             )))
          (loop for frame in result 
                for count fixnum below 1000 do
                (html :br)
                (emit-value frame)
                finally
                (when (> rlen 1000)
                  (html :br)
                  (emit-value "...")
                  )))))
     
     )))
