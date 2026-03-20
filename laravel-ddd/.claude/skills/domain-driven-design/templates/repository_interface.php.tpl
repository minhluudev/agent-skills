<?php

namespace Domain\{Domain}\Repositories;

use Domain\{Domain}\Models\{Subject};

/**
 * Repository interface for {Subject}.
 * Placed in the Domain layer — defines the contract without caring how it is fulfilled.
 * The implementation lives in infrastructure/{Domain}/Repositories/.
 */
interface {Subject}Repository
{
    public function findById(int $id): {Subject};

    public function save({Subject} ${lcSubject}): {Subject};

    public function delete({Subject} ${lcSubject}): void;

    /**
     * @return {Subject}[]
     */
    public function findAll(): array;
}
