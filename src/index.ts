///<reference path="../node_modules/@types/jquery/index.d.ts"/>

import moment = require("moment");


import 'jquery';
import 'bootstrap/dist/js/bootstrap.js';
import 'jquery-waypoints/waypoints.js';
import {Navbar} from "./navbar";

jQuery(() => {
   console.log('test 123', moment());
   Navbar.init();
    (<any> jQuery('.waypoint')).waypoint(function() {
        console.log('You have scrolled to a thing.');
        jQuery(this).addClass('wp-hit');
    },
        {offset : '100%'});
});
