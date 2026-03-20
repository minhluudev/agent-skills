<?php

namespace Domain\{Domain}\Actions;

use Domain\{Domain}\DTOs\{Subject}Data;
use Domain\{Domain}\Models\{Subject};
use Domain\{Domain}\Repositories\{Subject}Repository;

class {Verb}{Subject}Action
{
    public function __construct(
        private readonly {Subject}Repository $repository,
    ) {}

    public function handle({Subject}Data $data): {Subject}
    {
        // TODO: implement business logic here
        throw new \RuntimeException('Not implemented');
    }
}
