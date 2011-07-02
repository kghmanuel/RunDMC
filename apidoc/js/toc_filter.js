/* Copyright 2002-2011 MarkLogic Corporation.  All Rights Reserved. */
var previousFilterText = '';
var currentFilterText = '';

var previousFilterText2 = '';
var currentFilterText2 = '';

var previousFilterText3 = '';
var currentFilterText3 = '';

function filterConfigDetails(text, treeSelector) {
    var filter = text;

    // Filter only the first section of the TOC
    var allFunctionsRoot = $(treeSelector).children("li:first");

    // Make sure "All functions" container after each search (even if empty results)
    // TODO: Figure out how to directly call the "toggler" method from the treeview code rather than using this
    //       implementation-specific stuff
    expandSubTree(allFunctionsRoot);

    allFunctionsRoot.find("li").each(function() {
        $(this).removeClass("hide-detail");
        /*
        if (filter == '') {
            removeHighlightToText($(this));
        } else {
        */
        if (filter !== '') {
            if (hasText($(this),filter)) {
                    /* Temporarily disable highlighting as it's too slow (particularly when removing the highlight).
                     * Also, buggy in its interaction with the treeview control: branches may no longer respond to clicks
                     * (presumably due to the added spans).
                /*
                if ($(this).find("ul").length == 0)
                    "do nothing"
                    addHighlightToText($(this),filter); // then this is a leaf node, so u can perform highlight
                else {
                    */
                    // Expand the TOC sub-tree
                    expandSubTree($(this));
            } else {
                /*
                removeHighlightToText($(this));
                */
                $(this).addClass("hide-detail");
            }
        }            
    });
}

// This logic is essentially duplicated from the treeview plugin...bad, I know
function expandSubTree(li) {
  if (li.children().is("ul")) {
    li.removeClass("expandable").addClass("collapsable");//.addClass("open");
    if (li.is(".lastExpandable"))
      li.removeClass("lastExpandable").addClass("lastCollapsable");
    li.children("div").removeClass("expandable-hitarea").addClass("collapsable-hitarea");
    if (li.is(".lastExpandable-hitarea"))
      li.children("div").removeClass("lastExpandable-hitarea").addClass("lastCollapsable-hitarea");
    li.children("ul").css("display","block");
  }
}

function collapseSubTree(li) {
  if (li.children().is("ul")) {
    li.removeClass("collapsable").addClass("expandable");//.addClass("open");
    if (li.is(".lastCollapsable"))
      li.removeClass("lastCollapsable").addClass("lastExpandable");
    li.children("div").removeClass("collapsable-hitarea").addClass("expandable-hitarea");
    if (li.is(".lastCollapsable-hitarea"))
      li.children("div").removeClass("lastCollapsable-hitarea").addClass("lastExpandable-hitarea");
    li.children("ul").css("display","none");
  }
}


/* These functions implement the expand/collapse buttons */
function shallowExpandAll(ul) {
  ul.children("li").each(function(index) {
    expandSubTree($(this));
  });
}

function shallowCollapseAll(ul) {
  ul.children("li").each(function(index) {
    collapseSubTree($(this));
  });
}

function expandAll(ul) {
  shallowExpandAll(ul);
  if (ul.children("li").children().is("ul"))
    ul.children("li").children("ul").each(function() {
      expandAll($(this));
    });
}

function collapseAll(ul) {
  shallowCollapseAll(ul);
  if (ul.children("li").children().is("ul"))
    ul.children("li").children("ul").each(function() {
      collapseAll($(this));
    });
}




// For when someone clicks an intra-document link outside of the TOC itself
function showInTOC(a) {
  var items = a.addClass("selected").parents("ul, li").add( a.nextAll("ul") ).show();
  items.each(function(index) {
    expandSubTree($(this));
  });

  // Switch to the tab of the first instance
  var tab_index = a.first().parents(".tabbed_section").prevAll(".tabbed_section").length;
  $("#toc_tabs").tabs('select',tab_index);

}



function hasText(item,text) {
    var fieldTxt = item.text().toLowerCase();
    if (fieldTxt.indexOf(text.toLowerCase()) !== -1)
        return true;
    else
        return false;
}

function addHighlightToText(element,filter) {
    this.removeHighlightToText(element);
    element.find('a').each(function(){
        var elemHTML = $(this).html();
        elemHTML = elemHTML.replace(new RegExp(filter, 'g'),'<span class="toc_highlight">' + filter + '</span>');
        $(this).html(elemHTML);                
    });

}

function removeHighlightToText(element) {
    var elemHTML = element.html();
    element.find('.toc_highlight').each(function() {                
        var pureText = $(this).text();
        elemHTML = elemHTML.replace(new RegExp('<span class="toc_highlight">' + pureText + '</span>', 'g'),pureText);
        element.html(elemHTML);          
    });
}

function scrollTOC() {
  var container = $('#sub'),
      scrollTo = $('#sub a.selected'),
      extra = 80,
      currentTop = container.scrollTop(),
      headerHeight = container.offset().top,
      scrollTargetDistance = scrollTo.offset().top,
      scrollTarget = currentTop + scrollTargetDistance,
      scrollTargetAdjusted = scrollTarget - headerHeight - extra,
      minimumSpaceAtBottom = 10,
      minimumSpaceAtTop = 10;

/*
alert("currentTop: " + currentTop);
alert("scrollTargetDistance: " + scrollTargetDistance);
alert("scrollTarget: " + scrollTarget);
alert("scrollTargetAdjusted: " + scrollTargetAdjusted);
*/

  // Only scroll if necessary
  if (scrollTarget < currentTop + headerHeight + minimumSpaceAtTop
   || scrollTarget > currentTop + (container.height() - minimumSpaceAtBottom)) {
    container.animate({scrollTop: scrollTargetAdjusted}, 500);
  }
}


