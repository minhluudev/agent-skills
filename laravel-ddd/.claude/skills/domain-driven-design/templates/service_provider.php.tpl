<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

// Domain repositories
use Domain\{Domain}\Repositories\{Subject}Repository;
use Infrastructure\{Domain}\Repositories\Eloquent{Subject}Repository;

class DomainServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Bind each Repository interface to its Eloquent implementation.
        // Add one line here each time you create a new Repository.
        $this->app->bind({Subject}Repository::class, Eloquent{Subject}Repository::class);
    }
}
