<?php

namespace Domain\{Domain}\Handlers;

use Domain\{Domain}\Actions\{Subject}Action;
use Domain\{Domain}\Commands\{Subject}Command;

/**
 * CommandBus handler for {Subject}Command.
 * Delegates to the underlying Action — the handler is the bridge between the
 * CommandBus infrastructure and the domain Action layer.
 */
class {Subject}Handler
{
    public function __construct(
        private readonly {Subject}Action $action,
    ) {}

    public function handle({Subject}Command $command): void
    {
        // Extract data from the command and call the Action
        // $this->action->handle(...)
    }
}
