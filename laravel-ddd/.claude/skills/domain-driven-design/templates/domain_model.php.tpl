<?php

namespace Domain\{Domain}\Models;

use Domain\{Domain}\DTOs\{Subject}Data;

/**
 * Domain entity for {Subject}.
 * This is NOT an Eloquent model — it has no knowledge of the database.
 * Business rules and invariants belong here.
 */
class {Subject}
{
    public function __construct(
        public readonly ?int $id,
        public readonly string $name,
        // TODO: add domain properties
    ) {}

    /**
     * Create a new (unsaved) entity from a DTO.
     */
    public static function fromData({Subject}Data $data): self
    {
        return new self(
            id: null,
            name: $data->name,
        );
    }

    // TODO: add methods representing domain behaviour (not persistence concerns)
    // Example:
    // public function activate(): self
    // {
    //     return new self($this->id, $this->name, active: true);
    // }
}
