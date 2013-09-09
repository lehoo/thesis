default: Thesis.pdf 

Thesis.pdf: Thesis.tex
	pdflatex Thesis
	bibtex -min-crossrefs=300 Thesis
	pdflatex Thesis
	pdflatex Thesis
	pdflatex Thesis
	pdfopt Thesis.pdf Thesis-opt.pdf
	mv Thesis-opt.pdf Thesis.pdf

clean:
	/bin/rm -f *.dvi *.pdf *.aux *.log *.bbl *.blg *.out *.toc *.snm *.nav *.lof *.lot
