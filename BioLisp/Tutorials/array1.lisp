;;; -*- Package: biolisp; mode: lisp; base: 10; Syntax: Common-Lisp; -*-

;;; Copyright (c) 2002-2003 by Jeff Shrager, Mike Travers and JP Massar; 
;;; All rights reserved.

(in-package :bio)

;;; This software is made available for EDUCATIONAL PURPOSES
;;; ONLY, and WITHOUT ANY WARRANTY, express or implied, of
;;; its merchantability or fitness for a particular purpose. 


(defvar *syn6803-ontology*)
(defvar *hihara-results*)

(defun load-tutorial6-data ()
  (load "biol:data;hiharadat.lisp")
  (load "biol:data;tutorial6-ontology.lisp"))


(defun get-cyano-genes (target &optional (tree *syn6803-ontology*) extracting?)
  (cond ((and extracting? (listp tree) (stringp (second tree)))
	 ;; We've hit a leaf...
	 (list tree))			; give it up (listed for APPENDing)
	((and (listp tree) (stringp (second tree)) 
	      (string-equal target (car tree)))
	 ;; Not extracting, but this is leaf and a hit!
	 (list tree))			; Also give it up!
	(t (loop for entry in (cdr tree)
	       with extracting! = (or extracting? (string-equal target (car tree)))
	       when (listp entry)
	       append (get-cyano-genes target entry extracting!)))))

(defvar co2-genes)
(defvar photo-genes)

(defun show-cyano-genes-examples ()
  (let ((sample-targets
         '("Energy metabolism"
           "all"
           "sll1561"
           "CO2 fixation"
           "Photosynthesis and respiration"
           )))
    (terpri)
    (dolist (target sample-targets)
      (format t "Target: ~A~%  Number of genes: ~D~%"
              target (length (get-cyano-genes target)))))
  (setq co2-genes (get-cyano-genes "CO2 fixation"))
  (setq photo-genes (get-cyano-genes "Photosynthesis and respiration"))
  (values)
  )

(defvar *hihara-table* (make-hash-table :test #'equal))

(defun tablify-hihara-results ()
  (clrhash *hihara-table*)
  (loop for (name . results) in *hihara-results*
	do (setf (gethash name *hihara-table*) results)))

; (tablify-hihara-results)

;;; Now the analysis.  Assume that the GENES are: ("name" "description...")

(defun get-hihara-results (genes)
   (loop for gene in genes
	 collect (gethash (first gene) *hihara-table*)))

;;; That's all the results for the gene; We need some flexible way to 
;;; get the means for particular times.

(defun nth-mean (n values*)
  (loop with sum = 0.0
	with count = 0
	as values in values*
	do (incf count)
	(incf sum (nth n values))
	finally (return (/ sum count))))

;;; Now let's put it all together to get the means at all the time points
;;; for any given description in the cyano ontology:

(defun analyze-hihara-data (description)
  (loop for time in '(15 60 360 900) ; minutes for labeling
	as n from 0 by 1
	with results = (remove nil (get-hihara-results (get-cyano-genes description)))
	collect (cons time (nth-mean n results))))

(defun analyze-whole-tree! (&optional (tree *syn6803-ontology*) (depth 0))
  (loop for i from 0 to (* 2 depth) do (format t " ")) ; Put out indentation spaces.
  (format t "~a: " (car tree))
  (format t "~a~%" (analyze-hihara-data (car tree)))
  ;; Go down to the next levels in the tree...
  (loop for entry in (cdr tree)
	when (and (listp entry)
		  ;; But not when we're going to a specific gene!
		  (not (stringp (second entry)))) 
	do (analyze-whole-tree! entry (1+ depth))))

(defun qualitativize (value &optional (limit 2.0))
  (let ((log-value (log value 2))
	(log-limit (log limit 2)))
    (cond ((>= log-value log-limit) '+)
	  ((<= log-value (- log-limit)) '-)
	  (t 0))))
      
;;; Let's put all that together:

(defun qualitative-hihara-results (description &optional (limit 2.0))
  (loop for time-and-value in (analyze-hihara-data description)
	collect (qualitativize (cdr time-and-value) limit)))

;;; Now we need a place to store our results indexed by 
;;; the qualitative pattern:

(defvar *qualitative-pattern-table* (make-hash-table :test #'equal))

;;; And a new version of the tree analyzer that fills up the table:

(defun q-analyze-whole-tree! (&key (tree *syn6803-ontology*) (limit 2.0))
  ;; Clear the table only on the first call!
  (when (eq tree *syn6803-ontology*)
    (clrhash *qualitative-pattern-table*))
  ;; Compute the qualitative pattern for this level of the tree
  ;; and store it.
  (let* ((name (car tree))
	 (q-pattern (qualitative-hihara-results name limit)))
    (push name (gethash q-pattern *qualitative-pattern-table*)))
  ;; Go down to the next levels in the tree...
  (loop for entry in (cdr tree)
	when (and (listp entry)
		  ;; But not when we're going to a specific gene!
		  (not (stringp (second entry)))) 
	do (q-analyze-whole-tree! :tree entry :limit limit)))

;;; Now we need a function to display the results:

(defun display-q-patterns ()
  (loop for pattern being the hash-keys of *qualitative-pattern-table*
	using (hash-value names)
	do (unless (every #'(lambda (x) (eql x 0)) pattern)
             (format t "~a: ~s~%" pattern names))))

(defun qanal (&key (limit 2.0))
  (q-analyze-whole-tree! :limit limit)
  (display-q-patterns))
