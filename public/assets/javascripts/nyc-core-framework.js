$(document).ready(function () {

    ////////////////////////////////////////
    // Mutation observer - watch for RTL
    ////////////////////////////////////////

    var target = document.querySelector('html');

    var observer = new MutationObserver( function(mutations) {
        mutations.forEach( function() {
            var classes = target.getAttribute('class');
            var single_class = 'translated-rtl';
            if (classes.includes(single_class)) {
                target.setAttribute('dir', 'rtl');
            } else {
                target.setAttribute('dir', 'ltr');
            }
        });
    });

    var config = {
        attributes: true,
        attributeFilter: ['class']
    }

    observer.observe(target, config);

    ////////////////////////////////////////
    // Language, Search, and Menu Toggle
    ////////////////////////////////////////

    $('#global-language').on('show.bs.collapse', function () {
        $('#global-search').collapse('hide');
        $('#nav-primary').collapse('hide');
    });

    $('#global-search').on('show.bs.collapse', function () {
        $('#global-language').collapse('hide');
        $('#nav-primary').collapse('hide');
    });

    $('#nav-primary').on('show.bs.collapse', function () {
        $('#global-search').collapse('hide');
        $('#global-language').collapse('hide');
    });

    ////////////////////////////////////////
    // Language and Search Toggle Focus
    ////////////////////////////////////////

    $('#global-language').on('shown.bs.collapse', function () {
        $('.goog-te-combo').focus();
    }).on('show.bs.collapse', function () {
        $('.goog-te-combo').blur();
    });

    $('#global-search').on('shown.bs.collapse', function () {
        document.getElementById('global-search-bar').focus();
    }).on('show.bs.collapse', function () {
        document.getElementById('global-search-bar').blur();
    });

    ////////////////////////////////////////
    // Back to top
    ////////////////////////////////////////

    var scroll_speed = 800;

    if( $('#back-to-top').length ){

        $('#back-to-top > a').click(function() {
            $('body, html').animate({
                scrollTop: 0
            }, scroll_speed );
        });

        $(window).scroll(function() {

            var window_scroll = $(document).scrollTop();
            var primary_content = $('#primary-content').offset().top;

            if ( window_scroll > primary_content ) {
                $('#back-to-top').addClass('show');
            } else {
                $('#back-to-top').removeClass('show');
            }

        }).scroll();
    }

});

////////////////////////////////////////
// Google Translate Links
////////////////////////////////////////

$('.lang-select').click(function (e) {
    e.preventDefault();
    var lang = $(this).attr('data-lang')
    setLanguage(lang);
});

function setLanguage(theLang) {
    var theSelect = $('.goog-te-combo');
    var db = theSelect.get(0);
    theSelect.val(theLang);
    fireEvent(db, 'change');
}

function fireEvent(element, event) {
    if (document.createEventObject) {
        var evt = document.createEventObject();
        return element.fireEvent('on' + event, evt)
    } else {
        var evt = document.createEvent("HTMLEvents");
        // event type, bubbling, cancelable
        evt.initEvent(event, false, true);
        return !element.dispatchEvent(evt);
    }
}
// Display collections in ascending/descending order
$('#collection_title').click(function(){
    var isSelected = $("#sort option[value='title_sort desc']").attr("selected");
    //Sort records by title in ascending order
    if (typeof isSelected !== typeof undefined && isSelected !== false)
    {
        $("#sort option[value='title_sort asc']").attr("selected","selected");
        $("#sort option[value='title_sort desc']").removeAttr("selected");
        $("#sort_form").submit();
    }
    //Sort records by title in descending order
    else
    {
        $("#sort option[value='title_sort desc']").attr("selected","selected");
        $("#sort option[value='title_sort asc']").removeAttr("selected");
        $("#sort_form").submit();
    }
});
//Sort records by date in descending order
$('#collection_year').click(function(){
    var isSelected = $("#sort option[value='year_sort desc']").attr("selected");
    //Sort records by date in ascending order

    if (typeof isSelected !== typeof undefined && isSelected !== false) {
        $("#sort option[value='year_sort asc']").attr("selected", "selected");
        $("#sort option[value='year_sort desc']").removeAttr("selected");
        $("#sort_form").submit();
        $("#year-sort-icon").attr("class","fa fa-lg fa-caret-up");
    }
    //Sort records by date in descending order
    else {
        $("#sort option[value='year_sort desc']").attr("selected", "selected");
        $("#sort option[value='year_sort asc']").removeAttr("selected");
        $("#year-sort-icon").attr("class","fa fa-lg fa-caret-down");
        $("#sort_form").submit();

    }
});