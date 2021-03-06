import * as $ from "jquery";

export class Navbar {
    public static init() : void {
        $(function() {
            $('a.page-scroll').bind('click', function(event) {
                var $anchor = $(this);
                $('html, body').stop().animate({
                    scrollTop: $($anchor.attr('href')).offset().top - $(window).height()/3
                }, 1500, 'easeInOutExpo');
                event.preventDefault();
            });

            var createCookie = function(name : any,value : any,days : any) {
                let expires : string;
                if (days) {
                    let date = new Date();
                    date.setTime(date.getTime()+(days*24*60*60*1000));
                    expires = "; expires="+date.toDateString();
                } else {
                    expires = "";
                }
                document.cookie = name+"="+value+expires+"; path=/";
            };

            var readCookie = function(name : any) {
                let nameEQ = name + "=";
                let ca = document.cookie.split(';');
                for(let i=0;i < ca.length;i++) {
                    let c = ca[i];
                    while (c.charAt(0)==' ') c = c.substring(1,c.length);
                    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
                }
                return null;
            };

            $('.accept-cookie').click(function () {
                createCookie('cookie-accepted', true, 365);
                $('.cookie-policy').hide();
            });

            let val = readCookie('cookie-accepted');
            if (!val) {
                $('.cookie-policy').show();
            }
        });
        // Closes the Responsive Menu on Menu Item Click
        $('.navbar-collapse ul li a').click(function() {
            $('.navbar-toggle:visible').click();
        });

        var cbpAnimatedHeader = (function() {

            var docElem = document.documentElement,
                $header = $( '.navbar-default' ),
                $headersection = $('header'),
                didScroll = false,
                changeHeaderOn = 100;

            function init() {
                window.addEventListener( 'scroll', function( event ) {
                    if( !didScroll ) {
                        didScroll = true;
                        setTimeout( scrollPage, 250 );
                    }
                }, false );
            }

            function scrollPage() {
                var sy = scrollY();
                if (!$header.hasClass('navbar-always')) {
                    if (sy >= changeHeaderOn) {
                        $header.addClass('navbar-shrink');
                        $headersection.addClass('navbar-shrink');
                    }
                    else {
                        $header.removeClass('navbar-shrink');
                        $headersection.removeClass('navbar-shrink');
                    }
                }
                didScroll = false;
            }

            function scrollY() {
                return window.pageYOffset || docElem.scrollTop;
            }

            init();

        })();
    }
}


