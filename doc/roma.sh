#!/bin/bash
#
# Roma: transform TEI ODD files to schema and documentation
#
# Sebastian Rahtz, April 2005
# copyright: TEI Consortium
# license: GPL
# $Id: roma.sh 4811 2008-09-23 09:10:42Z rahtz $
#

makeODD() 
{
   echo "1. expand and simplify ODD "
   if test "x$lang" = "x"
   then
	xmllint --noent --xinclude $ODD \
	    | xsltproc -o $RESULTS/$ODD.compiled \
	    $SELECTEDSCHEMA $LANGUAGE $DOCLANG \
	    --stringparam useVersionFromTEI $useVersionFromTEI \
	    --stringparam TEIC $TEIC \
	    --stringparam TEISERVER $TEISERVER  \
	    --stringparam localsource "$LOCAL"  \
	    $DEBUG  $TEIXSLDIR/odds/odd2odd.xsl -
   else
	echo  [names translated to language $lang]
	xmllint --noent --xinclude $ODD \
	    | xsltproc \
	    --stringparam TEIC $TEIC \
	    --stringparam useVersionFromTEI $useVersionFromTEI \
	    --stringparam TEISERVER $TEISERVER  \
	    --stringparam localsource "$LOCAL"  \
	   $DEBUG  $TEIXSLDIR/odds/odd2odd.xsl - \
	    | xsltproc -o $RESULTS/$ODD.compiled $DEBUG $LANGUAGE $DOCLANG --stringparam TEISERVER $TEISERVER  \
	    $TEIXSLDIR/odds/translate-odd.xsl - 
   fi
}

makeRelax() 
{
   echo "2. make RELAX NG from compiled ODD"
   xsltproc $PATTERN $DEBUG $LANGUAGE $DOCLANG  $SELECTEDSCHEMA \
	     --stringparam parameterize $parameterize \
            --stringparam TEIC $TEIC \
            --stringparam outputDir $RESULTS   \
            $TEIXSLDIR/odds/odd2relax.xsl $RESULTS/$ODD.compiled
   (cd $RESULTS; \
   echo "3. make RELAX NG compact from XML"; \
   trang $schema.rng $schema.rnc  || die " trang conversion to RNC fails"; \
   xmllint --format $schema.rng > $$.xml; mv $$.xml $schema.rng )
}

makeXSD()
{
   echo "4. make XSD from RELAX NG"
   (cd $RESULTS; \
   trang  -o disable-abstract-elements $schema.rng $schema.xsd || die " trang fails";\
   test -f xml.xsd && perl -p -i -e 's+\"xml.xsd\"+\"http://www.w3.org/2004/10/xml.xsd\"+' $schema.xsd)
}

makeDTD()
{
   echo "5. make DTD from compiled ODD"
   xsltproc  $DEBUG $LANGUAGE $DOCLANG   $SELECTEDSCHEMA \
	    --stringparam parameterize $parameterize \
	    --stringparam TEIC $TEIC \
           --stringparam outputDir $RESULTS       \
           $TEIXSLDIR/odds/odd2dtd.xsl $RESULTS/$ODD.compiled
}

makeHTMLDOC() 
{
   echo "8. make HTML documentation $schema.doc.html "
   xsltproc 	-o $RESULTS/$schema.doc.html \
	$DEBUG  $LANGUAGE $DOCLANG --stringparam TEIC $TEIC \
	--stringparam STDOUT true \
	--stringparam splitLevel -1 \
	$DOCFLAGS $TEIXSLDIR/odds/odd2html.xsl $RESULTS/$ODD.compiled
}

makePDFDOC() 
{
   echo "7. make PDF documentation $schema.doc.pdf and $schema.doc.tex "
   xsltproc $DEBUG $LANGUAGE $DOCLANG --stringparam TEIC $TEIC \
	-o $RESULTS/$schema.doc.tex \
	$TEIXSLDIR/latex/tei.xsl $schema.doc.xml
   pdflatex $schema.doc.tex
}

makeXMLDOC() 
{
   echo "6. make expanded documented ODD $schema.doc.xml "
   xsltproc $DEBUG $LANGUAGE $DOCLANG --stringparam TEISERVER $TEISERVER  \
	--stringparam localsource "$LOCAL"  \
	--stringparam TEIC $TEIC \
	-o $RESULTS/$schema.doc.xml \
	$TEIXSLDIR/odds/odd2lite.xsl $RESULTS/$ODD.compiled 
}


die()
{
   echo; echo
   echo "ERROR: $@."
   D=`date "+%Y-%m-%d %H:%M:%S.%N"`
   echo "This was a fatal error. $D"
   exit 1
}

usageMsg()
{
echo "Roma -- reads in a TEI ODD file that specifies a schema, and tangles it"
echo "into RelaxNG schema, DTD, and W3C XML Schema, and can weave it into an"
echo "expanded, self-documented single ODD file. Note that only the first"
echo "<schemaSpec> encountered in the input ODD file is processed; all others"
echo "are ignored."
echo "  Usage: roma [options] schemaspec [output_directory]"
echo "  options, shown with defaults:"

echo "  --xsl=$TEIXSLDIR"
echo "  --teiserver=$TEISERVER"
echo "  --localsource=$LOCALSOURCE  # local copy of P5 sources"
echo "  options, binary switches:"
echo "  --compile          # create compiled file odd"
echo "  --debug            # leave temporary files, etc."
echo "  --doc              # create expanded documented ODD (TEI Lite XML)"
echo "  --dochtml          # create HTML version of doc"
echo "  --doclang=LANG     # language for documentation"
echo "  --docpdf           # create PDF version of doc"
echo "  --lang=LANG        # language for names of attrbutes and elements"
echo "  --nodtd            # suppress DTD creation"
echo "  --norelax          # suppress RELAX NG creation"
echo "  --noteic           # suppress TEI-specific features"
echo "  --noxsd            # suppress W3C XML Schema creation"
echo "  --useteiversion    # use version data from TEI P5"
echo "  --parameterize     # create parameterized DTD"
echo "  --patternprefix=STRING # prefix RELAX NG patterns with STRING"
echo "  --schema=NAME      # select name schema spec"
exit 1
}

# --------- main routine starts here --------- #
TEISERVER=http://tei.oucs.ox.ac.uk/Query/
TEIXSLDIR=/usr/share/xml/tei/stylesheet
useVersionFromTEI=true
LOCALSOURCE=
LOCAL=
TEIC=true
DOCFLAGS=
doclang=
lang=
compile=false
debug=false
dtd=true
relax=true
xsd=true
doc=false
docpdf=false
dochtml=false
parameterize=false
SELECTEDSCHEMA=
schema=
PATTERNPREFIX=
while test $# -gt 0; do
 case $1 in
   --compile)     compile=true;dtd=false;xsd=false;doc=false;relax=false;;
   --debug)       debug=true;;
   --doc)         doc=true;;
   --docflags=*)  DOCFLAGS=`echo $1 | sed 's/.*=//'`;;
   --dochtml)     dochtml=true;;
   --doclang=*)   doclang=`echo $1 | sed 's/.*=//'`;;
   --docpdf)      docpdf=true;;
   --lang=*)      lang=`echo $1 | sed 's/.*=//'`;;
   --localsource=*) LOCALSOURCE=`echo $1 | sed 's/.*=//'`;;
   --nodtd)       dtd=false;;
   --norelax)     relax=false;;
   --noteic)      TEIC=false;;
   --noxsd)       xsd=false;;
   --useteiversion=*) useVersionFromTEI=`echo $1 | sed 's/.*=//'`;;
   --parameterize)       parameterize=true;;
   --schema=*)    schema=`echo $1 | sed 's/.*=//'`;;
   --patternprefix=*) PATTERNPREFIX=`echo $1 | sed 's/.*=//'`;;
   --teiserver=*) TEISERVER=`echo $1 | sed 's/.*=//'`;;
   --xsl=*)       TEIXSLDIR=`echo $1 | sed 's/.*=//'`;;
   --help)        usageMsg;;
    *) if test "$1" = "${1#--}" ; then 
	   break
	else
	   echo "WARNING: Unrecognized option '$1' ignored"
	   echo "For usage syntax issue $0 --help"
	fi ;;
 esac
 shift
done
ODD=${1:?"no schemaspec (i.e., ODD file) supplied; for usage syntax issue $0 --help"}
RESULTS=${2:-RomaResults}
H=`pwd`
D=`date "+%Y-%m-%d %H:%M:%S"`
echo "========= $D Roma starts, info:"
echo "Test for software: xmllint, xsltproc, trang, and perl"
which xmllint || die "you do not have xmllint"
which xsltproc || die "you do not have xsltproc"
which trang || die "you do not have trang"
which perl || die "you do not have perl"
test -f $ODD || die "file $ODD does not exist"
echo "TEI stylesheet tree: $TEIXSLDIR"
test -d $TEIXSLDIR/odds || \
    GET -e -d $TEIXSLDIR/odds/odd2odd.xsl > /dev/null || \
    die "stylesheet location $TEIXSLDIR is not accessible"
if test "x$schema" = "x"
then
schema=$(xsltproc --xinclude $TEIXSLDIR/odds/extract-schemaSpec-ident.xsl $1 | head -1)
schema=${schema:?"Unable to ascertain ident= of <schemaSpec>"}
fi
echo "Results to: $RESULTS"
mkdir -p $RESULTS || die "cannot make directory $RESULTS"
D=`date "+%Y-%m-%d %H:%M:%S.%N"`
echo "Process $ODD to create $schema{.dtd|.xsd|.doc.xml|.rng|.rnc} in $RESULTS"
echo "========= $D Roma starts, execution:"
if test "x$PATTERNPREFIX" = "x"
then
  PATTERN=" "
else
  PATTERN=" --stringparam patternPrefix $PATTERNPREFIX"
fi

if $debug
then
   DEBUG=" --stringparam verbose true"
else
   if $compile
	then
	DEBUG=" --stringparam stripped true"
   else
	DEBUG=" "
   fi
fi

SELECTEDSCHEMA=" --stringparam selectedSchema $schema "

if test "x$doclang" = "x"
then
 DOCLANG=" "
else 
 DOCLANG=" --stringparam doclang $doclang --stringparam documentationLanguage $doclang"
fi

if test "x$lang" = "x"
then
 LANGUAGE=" "
else 
 LANGUAGE=" --stringparam lang $lang "
fi
if test "x$LOCALSOURCE" = "x"
then
   echo using $TEISERVER to access TEI database
else
   echo using $LOCALSOURCE to gather information about TEI 
cat > subset.xsl <<EOF
<xsl:stylesheet version="1.0"
 xmlns:tei="http://www.tei-c.org/ns/1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:key name="ALL" use="1" 
   match="tei:elementSpec|tei:macroSpec|tei:classSpec|tei:moduleSpec"/>
 <xsl:template match="/">
   <tei:TEI>
     <xsl:copy-of select="tei:TEI/tei:teiHeader"/>
     <xsl:copy-of select="key('ALL',1)"/>
   </tei:TEI>
</xsl:template>
</xsl:stylesheet>
EOF
xmllint --noent --xinclude $LOCALSOURCE | xsltproc -o tei$$.xml $DEBUG subset.xsl - || die "failed to extract subset from $LOCALSOURCE "
LOCAL=$H/tei$$.xml
fi

makeODD
( $relax || $xsd ) && makeRelax
if $xsd 
then
  if ! $relax 
  then
     echo Ignored --norelax, RELAX NG required\
    to generate W3C XML Schema
  fi
  makeXSD
fi
$dtd && makeDTD
$dochtml && doc=true
$docpdf && doc=true
if $doc
then 
   makeXMLDOC
   if $docpdf
   then
	makePDFDOC
   fi
fi
$dochtml && makeHTMLDOC
$compile || $debug || rm  $RESULTS/$ODD.compiled
test -f subset.xsl && rm subset.xsl
test -f tei$$.xml && rm tei$$.xml
D=`date "+%Y-%m-%d %H:%M:%S.%N"`
echo "========= $D Roma ends"  