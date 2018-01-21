;;; Copyright 2014 Clozure Associates
;;;
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.

(in-package :ccldoc)

(defun output-html (doc filename &key (external-format :default) (if-exists :supersede)
				   stylesheet)
  (with-open-file (s filename :direction :output :if-exists if-exists
		     :external-format external-format)
    (format s "<!DOCTYPE html>~%")
    (format s "<html>~%")
    (format s "<head>~%")
    (format s "<meta charset=\"utf-8\">~%")
    (when stylesheet
      (format s "<link rel=\"stylesheet\" type=\"text/css\" href=\"~a\" />~%"
	      stylesheet))
    (format s "<title>~%")
    (write-html (clause-title doc) s)
    (format s "</title>~%")
    (format s "</head>~%")
    (write-html doc s)
    (format s "</html>~%")
    (truename s)))

(defun write-html-toc (document stream &optional (depth 2))
  (let* ((body-clauses (clause-body document))
	 (sections (if (listp body-clauses)
		       ;; My Emacs formating, should I change it?
		       (remove-if-not #'(lambda (clause)
					  (typep clause 'section))
				      body-clauses)
		       (and (typep body-clauses 'section)
			    (list body-clauses)))))
    (format stream "<ul style=\"list-style: none\">~%")
    (dolist (section sections)
      (format stream "~&<li><a href=\"#~a\">~%" (clause-external-id section))
      (write-html (clause-title section) stream)
      (format stream "</a>~%")
      (when (plusp (1- depth))
	(write-html-toc section stream (1- depth))))
    (format stream "</ul>~%")))

(defun write-html-sidebar (document stream)
  (format stream "<div class=\"sidebar\">~%")
  (write-html-toc document stream 1)
  (format stream "</div>~%"))

(defun clause-chapter (clause)
  (loop
    (setq clause (clause-parent clause))
    (when (or (null clause)
	      (= (section-level clause) 1))
      (return clause))))

(defmethod write-html ((clause document) stream)
  (format stream "<body>~%")
  ;; (write-string "<h1>" stream)
  ;; (write-html (clause-title clause) stream)
  ;; (write-string "</h1>" stream)
  (fresh-line stream)
  (write-string "<div class=toc>" stream)
  (write-html-sidebar clause stream)
  (write-string "</div>" stream)
  (write-string "<div class=body>" stream)
  (write-html (clause-body clause) stream)
  (write-string "</div>" stream)
  (format stream "</body>~%"))

(defmethod write-html ((clause index-section) stream)
  (write-string "<div class=index>" stream)
  (write-string "<h1>" stream)
  (write-html (clause-title clause) stream)
  (write-string "</h1>" stream)
  (when (clause-body clause)
    (write-html (clause-body clause) stream))
  (write-string "</div>" stream))

(defmethod write-html ((clause glossary-section) stream)
  (write-string "<div class=glossary>" stream)
  (write-string "<h1>" stream)
  (write-html (clause-title clause) stream)
  (write-string "</h1>" stream)
  (let ((entries (clause-body clause)))
    (when entries
      (write-string "<dl>" stream)
      (dolist (entry entries)
	(write-html entry stream))
      (write-string "</dl>" stream)))
  (write-string "</div>" stream))

(defmethod write-html ((clause glossentry) stream)
  (write-string "<dt>" stream)
  (write-html (clause-term clause) stream)
  (write-string "<dd>" stream)
  (write-html (clause-body clause) stream))

(defmethod write-html ((clause section) stream)
  (if (typep (ancestor-of-type clause 'named-clause) 'definition)
      (write-html (clause-body clause) stream)
      (let ((tag (case (section-level clause)
		   (0 :h1)
		   (1 :h2)
		   (2 :h3)
		   (3 :h4)
		   (4 :h5)
		   (otherwise :h6))))
	(format stream "<~a>" tag)
	(write-html (clause-title clause) stream)
	(format stream "</~a>~%" tag)
	(format stream "<div class=\"section\">~%")
	(when (<= (section-level clause) 1)
	  (write-html-toc clause stream))
	(write-html (clause-body clause) stream)
	(format stream "</div>~%"))))

(defmethod write-html ((clause code-block) stream)
  (write-string "<pre class=\"source-code\">" stream)
  (write-html (clause-body clause) stream)
  (format stream "~&</pre>~%"))

(defmethod write-html ((clause block) stream)
  (format stream "<blockquote>~%")
  (write-html (clause-body clause) stream)
  (format stream "~&</blockquote>~%"))

(defmethod write-html ((clause para) stream)
  (write-string "<p>" stream)
  (let ((body (clause-body clause)))
    (when body
      (write-html (clause-body clause) stream)))
  (write-string "</p>" stream)
  (fresh-line stream))

(defmethod write-html ((clause docerror) stream)
  (write-string "<span style=\"background-color: red\">" stream)
  (write-string (clause-text clause) stream)
  (write-string "</span>" stream)
  (fresh-line stream))

(defmethod write-html ((clause link) stream)
  (format stream "<a href=\"~a\">" (link-url clause))
  (write-html (clause-body clause) stream)
  (format stream "</a>~%"))

(defmethod write-html ((clause table) stream)
  (write-string "<table>" stream)
  (format stream "~&<caption>")
  (write-html (clause-title clause) stream)
  (format stream "</caption>~%")
  (loop for row across (clause-items clause)
	do (write-html row stream))
  (write-string "</table>" stream)
  (fresh-line stream))

(defmethod write-html ((clause row) stream)
  (write-string "<tr>" stream)
  (loop for item across (clause-items clause)
	do (progn (write-string "<td>" stream)
		  (write-html item stream)
		  (fresh-line stream)))
  (write-string "</tr>" stream)
  (fresh-line stream))

(defmethod write-html ((clause listing) stream)
  (multiple-value-bind (start-tag end-tag)
      (case (listing-type clause)
	(:bullet (values "<ul>" "</ul>"))
	(:number (values "<ol>" "</ol>"))
	(:definition (values "<dl>" "</dl>"))
	(otherwise (values "" "")))
    (write-string start-tag stream)
    (loop for item across (clause-items clause)
	  do (progn
	       (when (member (listing-type clause) '(:bullet :number))
		 (write-string "<li>" stream))
	       (write-html item stream)))
    (write-string end-tag stream)
    (fresh-line stream)))

(defmethod write-html ((clause indexed-clause) stream)
  (write-html (clause-body clause) stream))

(defmethod write-html ((clause markup) stream)
  (let ((tag (ecase (markup-type clause)
	       (:emphasis :em)
	       (:code :code)
	       (:param :i)
	       (:sample :i)
	       (:system :code))))
    (format stream "<~a>" tag)
    (write-html (clause-body clause) stream)
    (format stream "</~a>" tag)))

(defmethod write-html ((clause item) stream)
  (let ((body (clause-body clause)))
    (when body
      (write-html (clause-body clause) stream)
      (fresh-line stream))))

(defmethod write-html ((clause term-item) stream)
  (write-string "<dt>" stream)
  (write-html (clause-term clause) stream)
  (write-string "</dt>" stream)
  (fresh-line stream)
  (write-string "<dd>" stream)
  (write-html (clause-body clause) stream)
  (write-string "</dd>" stream)
  (fresh-line stream))

(defmethod write-html ((clause xref) stream)
  (format stream "<a href=\"#~a\">" (clause-external-id (xref-target clause)))
  (write-html (or (clause-body clause)
		  (xref-default-body clause))
	      stream)
  (write-string "</a>" stream))

;;l This is pretty much an ad-hoc disaster.
(defun html-formatted-signature (signature)
  (let ((words (split-sequence #\space
			       (cl-who:escape-string (string-downcase
						      signature)))))
    (with-output-to-string (s)
      (format s "<code>~a</code> " (pop words))
      (dolist (w words)
        (cond ((member w (list "&amp;key" "&amp;optional" "&amp;rest" "&amp;allow-other-keys" "&amp;body")
                       :test 'equalp)
               (format s "<code>~a</code> " w))
              ((and (char= (char w 0) #\()
                    (not (char= (char w (1- (length w))) #\))))
               (write-string " (" s)
               (format s "<i>~a</i> " (cl-who:escape-string (string-trim "(" w))))
              ((and (not (char= (char w 0) #\())
                    (char= (char w (1- (length w))) #\)))
               (format s "<i>~a</i>" (cl-who:escape-string (string-trim ")" w)))
               (write-string ") " s))
              (t
               (format s "<i>~a</i> " (cl-who:escape-string w))))
))))

(defmethod write-html ((clause definition) stream)
  (write-string "<div class=definition>" stream)
  (fresh-line stream)
  (write-string (html-formatted-signature (clause-text (definition-signature
							   clause)))
		stream)
  (write-string "<span class=\"definition-kind\">[" stream)
  (write-html (dspec-type-name (clause-name clause)) stream)
  (write-string "]</span>" stream)
  (when (definition-summary clause)
    (write-string "<p>" stream)
    (write-html (definition-summary clause) stream)
    (write-string "</p>" stream)
    (fresh-line stream))
  (write-html (clause-body clause) stream)
  (write-string "</div>" stream)
  (fresh-line stream))

(defmethod write-html ((clause cons) stream)
  (dolist (c clause)
    (write-html c stream)))

(defmethod write-html ((clause string) stream)
  (write-string (cl-who:escape-string-minimal clause) stream))

(defmethod write-html ((clause null) stream)
  (declare (ignore stream))
  (cerror "return nil" "null clause"))

(defmethod write-html :before ((clause named-clause) stream)
  (when (clause-name clause)
    (format stream "<a id=\"~a\"></a>~%" (clause-external-id clause))))
