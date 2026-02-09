<?php

use Illuminate\Support\Str;

if (! function_exists('show_or_mask')) {
    function show_or_mask(
        mixed $value,
        bool $show = false,
        string $maskChar = '•',
    ): string {
        if ($show) {
            return (string) $value;
        }

        return Str::mask((string) $value, $maskChar, 0);
    }
}