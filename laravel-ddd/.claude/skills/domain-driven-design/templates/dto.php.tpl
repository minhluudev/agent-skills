<?php

namespace Domain\{Domain}\DTOs;

use App\Http\Requests\{Subject}Request;

class {Subject}Data
{
    public function __construct(
        public readonly string $name,
        // TODO: add typed properties matching your domain object
    ) {}

    /**
     * Construct from an HTTP Form Request.
     * Use this at the Controller boundary to convert validated input into a domain DTO.
     */
    public static function fromRequest({Subject}Request $request): self
    {
        return new self(
            name: $request->input('name'),
        );
    }

    /**
     * Construct from a plain array (e.g., from a CSV import, queue payload, or test fixture).
     */
    public static function fromArray(array $data): self
    {
        return new self(
            name: $data['name'],
        );
    }
}
