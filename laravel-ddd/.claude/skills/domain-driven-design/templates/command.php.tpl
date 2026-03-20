<?php

namespace Domain\{Domain}\Commands;

/**
 * Command for the CommandBus pattern.
 * Acts as a typed DTO carrying all the data needed to execute a specific operation.
 * Paired with {Subject}Handler.
 */
class {Subject}Command
{
    private string $name;

    // TODO: add properties for each piece of data the handler needs

    public function getName(): string
    {
        return $this->name;
    }

    public function setName(string $name): void
    {
        $this->name = $name;
    }
}
