@recognizer : TextRecognizer
@pending_states : Channel(Task?)
@results : Channel(Result)
@worker_done : Channel(Nil)
@mutation_callback : Proc(State, Nil)
@full_screen : ScreenRegion
@active_region : ScreenRegion
@last_enqueued_task : Task? = nil
@latest_result : Result? = nil
@closed = false

include Initialize
include Public
include Private
